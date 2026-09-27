-- 026_new_user_profile_public_id.sql
-- Fehlerbehebung (27.09.2026): Neue Konten konnten sich nicht anmelden (erster TestFlight-Test).
--
-- Der Trigger on_auth_user_created (handle_new_user) legt beim Registrieren eine Profilzeile an – aber ohne
-- public_id und created_at. Die App liest das Profil, Profile.publicId ist nicht optional, das Dekodieren
-- scheitert. Weil die Zeile existiert, meldet der Server kein PGRST116, und die App legt das Profil auch nicht
-- selbst an (OnboardingService.createProfileForNewUser). Ergebnis: Anmeldung auf dem Server erfolgreich,
-- in der App bleibt der Anmeldebildschirm. Live gesehen am 27.09.2026 bei einem neuen Konto (Magic Link).
-- Betroffen: jedes Konto, das nach dem Anlegen des Triggers registriert wurde.
--
-- Neu: Der Trigger vergibt public_id im selben Format wie die App (8 Zeichen A–Z/0–9, eindeutig) und setzt
-- created_at/updated_at. Bestehende Profile ohne public_id werden einmalig nachgetragen; der Trigger
-- trg_profiles_public_id_immutable erlaubt das, weil der alte Wert NULL ist.

create or replace function public.generate_profile_public_id()
returns text
language plpgsql
set search_path to ''
as $$
declare
  alphabet constant text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  candidate text;
begin
  loop
    candidate := '';
    for i in 1..8 loop
      candidate := candidate || substr(alphabet, 1 + floor(random() * 36)::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles p where p.public_id = candidate);
  end loop;
  return candidate;
end;
$$;

revoke execute on function public.generate_profile_public_id() from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  insert into public.profiles (id, full_name, avatar_url, public_id, created_at, updated_at)
  values (new.id,
          new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'avatar_url',
          public.generate_profile_public_id(),
          now(),
          now());
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Einmalig: Profile ohne public_id nachtragen.
update public.profiles
set public_id  = public.generate_profile_public_id(),
    created_at = coalesce(created_at, now()),
    updated_at = coalesce(updated_at, now())
where public_id is null;
