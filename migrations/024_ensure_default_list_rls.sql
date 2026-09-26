-- 024_ensure_default_list_rls.sql
-- Fehlerbehebung (26.09.2026): Anmelden auf einem neuen Gerät scheiterte mit 403.
--
-- ensure_default_list (Migration 018) legte die Standardliste mit
--   INSERT … ON CONFLICT (owner_id) WHERE is_default DO NOTHING
-- an. Existiert die Standardliste schon (jeder Start nach dem ersten), lehnt Postgres diese Anweisung unter
-- den Regeln aus Migration 019 mit „new row violates row-level security policy for table lists“ (42501) ab
-- – live nachgestellt als Testkonto. Die App bricht die Anmeldung dann ab und zeigt wieder „Anmelden“.
-- Betroffen: jeder Start ohne lokale Kopie der Listen (Neuinstallation, neues Gerät, Simulator).
--
-- Neu: nur einfügen, wenn noch keine Standardliste existiert; ein gleichzeitiger Start eines anderen Geräts
-- (Eindeutigkeit owner_id bei is_default) wird abgefangen. Ergebnis und Rechte bleiben gleich.

create or replace function public.ensure_default_list(p_id uuid default null, p_title text default 'My List')
returns setof public.lists
language plpgsql
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not exists (select 1 from public.lists l where l.owner_id = auth.uid() and l.is_default) then
    begin
      insert into public.lists (id, owner_id, title, is_default)
      values (coalesce(p_id, gen_random_uuid()), auth.uid(), coalesce(nullif(btrim(p_title), ''), 'My List'), true);
    exception when unique_violation then
      null;                                   -- anderes Gerät war schneller: dessen Liste gilt
    end;
  end if;
  return query select * from public.lists l where l.owner_id = auth.uid() and l.is_default;
end;
$$;
