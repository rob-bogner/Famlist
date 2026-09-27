-- 027_account_archive.sql
-- Konto archivieren statt sofort löschen (Entscheidung Robert, 27.09.2026; Plan: design-handoff/ACCOUNT_ARCHIVE_PLAN.md).
--
-- „Konto löschen“ archiviert das Konto 60 Tage lang:
-- - Die Mitgliedschaften werden gesichert und gelöscht. Weil alle Zugriffsregeln über die Mitgliedschaft laufen
--   (private.accessible_list_ids & Co.), verschwinden geteilte Listen sofort bei allen Mitgliedern. Der Trigger
--   trg_list_member_removed meldet das deren Apps per Realtime (member_removed).
-- - Besitzer fremder Listen bekommen einen gespeicherten Hinweis (account_notices) und ein Realtime-Ereignis.
-- - Das archivierte Konto selbst darf sich anmelden (zum Wiederherstellen), sieht aber keine Listen mehr und darf
--   keine anlegen oder ändern – auch nicht mit einem noch gültigen Token auf einem anderen Gerät.
-- - restore_my_account() schreibt alles zurück, außer der Besitzer hat die Person in der Zwischenzeit entfernt.
-- Endgültiges Löschen (inkl. Fotos) folgt in Migration 028.
--
-- Der Archivzustand liegt bewusst NICHT in profiles: profiles_update erlaubt jedem, die eigene Zeile zu ändern –
-- die Löschfrist wäre sonst selbst verschiebbar. profiles bleibt für TestFlight-Build 1 unverändert.

-- ---------------------------------------------------------------------------------------------------------------
-- Tabellen
-- ---------------------------------------------------------------------------------------------------------------

create table private.account_archive (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  archived_at  timestamptz not null default now(),
  purge_after  timestamptz not null,
  display_name text
);

create table private.archived_memberships (
  list_id     uuid not null references public.lists(id) on delete cascade,
  profile_id  uuid not null,
  role        text not null,
  added_at    timestamptz not null,
  -- owner_archived: der Listenbesitzer ist archiviert · member_archived: das Mitglied ist archiviert
  reason      text not null check (reason in ('owner_archived', 'member_archived')),
  archived_at timestamptz not null default now(),
  primary key (list_id, profile_id)
);
create index archived_memberships_profile_idx on private.archived_memberships (profile_id);

alter table private.account_archive enable row level security;
alter table private.archived_memberships enable row level security;
revoke all on private.account_archive, private.archived_memberships from public, anon, authenticated;

create table public.account_notices (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  list_id      uuid references public.lists(id) on delete cascade,
  subject_id   uuid,
  subject_name text,
  kind         text not null check (kind in ('member_archived')),
  created_at   timestamptz not null default now(),
  seen_at      timestamptz
);
create index account_notices_unseen_idx on public.account_notices (recipient_id) where seen_at is null;
create index account_notices_subject_idx on public.account_notices (subject_id);

alter table public.account_notices enable row level security;
revoke all on public.account_notices from public, anon, authenticated;
grant select on public.account_notices to authenticated;
create policy account_notices_select on public.account_notices
  for select to authenticated using (recipient_id = (select auth.uid()));

-- ---------------------------------------------------------------------------------------------------------------
-- Hilfsfunktionen und Sperre für archivierte Konten
-- ---------------------------------------------------------------------------------------------------------------

create or replace function private.is_archived(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (select 1 from private.account_archive a where a.user_id = p_user);
$$;

create or replace function private.caller_active()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select not private.is_archived((select auth.uid()));
$$;

revoke execute on function private.is_archived(uuid), private.caller_active() from public, anon;
grant execute on function private.is_archived(uuid), private.caller_active() to authenticated, service_role;

create or replace function private.accessible_list_ids()
returns setof uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select l.id from public.lists l
  where l.owner_id = (select auth.uid()) and (select private.caller_active())
  union
  select m.list_id from public.list_members m
  where m.profile_id = (select auth.uid()) and (select private.caller_active());
$$;

create or replace function private.is_list_owner(p_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select private.caller_active() and exists (
    select 1
    from public.lists l
    where l.id = p_list_id
      and l.owner_id = auth.uid()
  );
$$;

create or replace function private.is_list_member(p_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select private.caller_active() and exists (
    select 1
    from public.list_members m
    where m.list_id = p_list_id
      and m.profile_id = auth.uid()
  );
$$;

drop policy lists_insert on public.lists;
create policy lists_insert on public.lists for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select private.caller_active()));

drop policy lists_update on public.lists;
create policy lists_update on public.lists for update to authenticated
  using (owner_id = (select auth.uid()) and (select private.caller_active()))
  with check (owner_id = (select auth.uid()) and (select private.caller_active()));

drop policy lists_delete on public.lists;
create policy lists_delete on public.lists for delete to authenticated
  using (owner_id = (select auth.uid()) and (select private.caller_active()));

-- Einladungen: archivierte Aufrufer und archivierte Listenbesitzer werden abgelehnt.
create or replace function public.accept_list_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_uid uuid := auth.uid();
  v_list uuid;
  v_owner uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  IF private.is_archived(v_uid) THEN
    RAISE EXCEPTION 'account archived' USING ERRCODE = '42501';
  END IF;

  SELECT i.list_id, l.owner_id INTO v_list, v_owner
  FROM public.list_invites i
  JOIN public.lists l ON l.id = i.list_id
  WHERE i.token = p_token AND i.revoked_at IS NULL AND i.expires_at > now()
    AND NOT private.is_archived(l.owner_id);

  IF v_list IS NULL THEN
    RAISE EXCEPTION 'invite invalid or expired' USING ERRCODE = 'P0002';
  END IF;

  IF v_owner <> v_uid THEN
    INSERT INTO public.list_members (list_id, profile_id, role)
    VALUES (v_list, v_uid, 'collaborator')
    ON CONFLICT (list_id, profile_id) DO NOTHING;
  END IF;

  RETURN v_list;
END;
$$;

create or replace function public.invite_preview_by_token(p_token text)
returns table(list_id uuid, title text, item_count integer, member_count integer, inviter_name text)
language sql
stable
security definer
set search_path to 'public'
as $$
  SELECT l.id,
         l.title,
         (SELECT count(*) FROM public.items it
           WHERE it.list_id = l.id AND coalesce(it.tombstone, false) = false)::int,
         ((SELECT count(*) FROM public.list_members m WHERE m.list_id = l.id) + 1)::int,
         coalesce(nullif(p.full_name, ''), nullif(p.username, ''), p.public_id)
  FROM public.list_invites i
  JOIN public.lists l ON l.id = i.list_id
  LEFT JOIN public.profiles p ON p.id = i.created_by
  WHERE i.token = p_token
    AND i.revoked_at IS NULL
    AND i.expires_at > now()
    AND auth.uid() IS NOT NULL
    AND private.caller_active()
    AND NOT private.is_archived(l.owner_id);
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- Archivieren
-- ---------------------------------------------------------------------------------------------------------------

create or replace function private.archive_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_name   text;
  v_purge  timestamptz := now() + interval '60 days';
  v_notice uuid;
  r        record;
begin
  if p_user is null then
    raise exception 'user required' using errcode = '22004';
  end if;
  if private.is_archived(p_user) then
    return;                                            -- schon archiviert: nichts doppelt ausführen
  end if;

  select coalesce(nullif(p.full_name, ''), nullif(p.username, ''), p.public_id)
    into v_name from public.profiles p where p.id = p_user;

  -- Eigene Listen: alle Mitglieder sichern.
  insert into private.archived_memberships (list_id, profile_id, role, added_at, reason)
  select m.list_id, m.profile_id, m.role, m.added_at, 'owner_archived'
  from public.list_members m
  join public.lists l on l.id = m.list_id
  where l.owner_id = p_user
  on conflict (list_id, profile_id) do nothing;

  -- Fremde Listen: eigene Mitgliedschaft sichern, Besitzer benachrichtigen.
  for r in
    select m.list_id, m.role, m.added_at, l.owner_id
    from public.list_members m
    join public.lists l on l.id = m.list_id
    where m.profile_id = p_user and l.owner_id <> p_user
  loop
    insert into private.archived_memberships (list_id, profile_id, role, added_at, reason)
    values (r.list_id, p_user, r.role, r.added_at, 'member_archived')
    on conflict (list_id, profile_id) do nothing;

    insert into public.account_notices (recipient_id, list_id, subject_id, subject_name, kind)
    values (r.owner_id, r.list_id, p_user, v_name, 'member_archived')
    returning id into v_notice;

    perform realtime.send(
      jsonb_build_object('notice_id', v_notice, 'list_id', r.list_id, 'subject_name', v_name),
      'member_archived', 'user:' || r.owner_id::text, true);
  end loop;

  -- Löschen der Mitgliedschaften löst trg_list_member_removed aus (Realtime member_removed, Einladungen widerrufen).
  delete from public.list_members m using public.lists l
  where l.id = m.list_id and l.owner_id = p_user;
  delete from public.list_members where profile_id = p_user;

  update public.list_invites set revoked_at = now()
  where revoked_at is null and list_id in (select l.id from public.lists l where l.owner_id = p_user);

  insert into private.account_archive (user_id, archived_at, purge_after, display_name)
  values (p_user, now(), v_purge, v_name);

  -- Andere Geräte desselben Kontos melden sich ab.
  perform realtime.send(jsonb_build_object('purge_after', v_purge), 'account_archived', 'user:' || p_user::text, true);
  delete from auth.sessions where user_id = p_user;
end;
$$;

revoke execute on function private.archive_account(uuid) from public, anon, authenticated;

-- Name und Signatur bleiben: TestFlight-Build 1 ruft genau diese RPC auf.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  perform private.archive_account(auth.uid());
end;
$$;

create or replace function public.my_account_status()
returns table(archived_at timestamptz, purge_after timestamptz)
language sql
stable
security definer
set search_path to ''
as $$
  select a.archived_at, a.purge_after from private.account_archive a where a.user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- Wiederherstellen
-- ---------------------------------------------------------------------------------------------------------------

create or replace function public.restore_my_account()
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_purge timestamptz;
  r       record;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select a.purge_after into v_purge from private.account_archive a where a.user_id = v_uid for update;
  if v_purge is null then
    return false;                                      -- nicht archiviert
  end if;
  if v_purge <= now() then
    raise exception 'archive expired' using errcode = 'P0002';
  end if;

  delete from private.account_archive where user_id = v_uid;   -- ab hier gilt das Konto als aktiv

  -- Mitglieder meiner Listen: aktive zurück, selbst archivierte warten auf ihre eigene Wiederherstellung.
  for r in
    select a.list_id, a.profile_id, a.role, a.added_at, private.is_archived(a.profile_id) as member_archived
    from private.archived_memberships a
    join public.lists l on l.id = a.list_id
    where l.owner_id = v_uid and a.reason = 'owner_archived'
  loop
    if r.member_archived then
      update private.archived_memberships set reason = 'member_archived'
      where list_id = r.list_id and profile_id = r.profile_id;
    else
      if exists (select 1 from public.profiles p where p.id = r.profile_id) then
        insert into public.list_members (list_id, profile_id, role, added_at)
        values (r.list_id, r.profile_id, r.role, r.added_at)
        on conflict (list_id, profile_id) do nothing;
        perform realtime.send(jsonb_build_object('list_id', r.list_id), 'member_restored',
                              'user:' || r.profile_id::text, true);
      end if;
      delete from private.archived_memberships where list_id = r.list_id and profile_id = r.profile_id;
    end if;
  end loop;

  -- Meine Mitgliedschaften in fremden Listen: zurück, außer der Besitzer ist selbst archiviert.
  for r in
    select a.list_id, a.role, a.added_at, private.is_archived(l.owner_id) as owner_archived
    from private.archived_memberships a
    join public.lists l on l.id = a.list_id
    where a.profile_id = v_uid and a.reason = 'member_archived'
  loop
    if r.owner_archived then
      update private.archived_memberships set reason = 'owner_archived'
      where list_id = r.list_id and profile_id = v_uid;
    else
      insert into public.list_members (list_id, profile_id, role, added_at)
      values (r.list_id, v_uid, r.role, r.added_at)
      on conflict (list_id, profile_id) do nothing;
      delete from private.archived_memberships where list_id = r.list_id and profile_id = v_uid;
    end if;
  end loop;

  -- Noch nicht gezeigte Hinweise „hat sein Konto gelöscht“ sind jetzt falsch.
  delete from public.account_notices where subject_id = v_uid and seen_at is null;
  return true;
end;
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- Besitzer: archivierte Mitglieder, Hinweise
-- ---------------------------------------------------------------------------------------------------------------

create or replace function public.archived_list_members(p_list_id uuid)
returns table(profile_id uuid, name text, purge_after timestamptz)
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not private.is_list_owner(p_list_id) then
    raise exception 'not list owner' using errcode = '42501';
  end if;
  return query
    select a.profile_id, ac.display_name, ac.purge_after
    from private.archived_memberships a
    join private.account_archive ac on ac.user_id = a.profile_id
    where a.list_id = p_list_id and a.reason = 'member_archived'
    order by a.added_at;
end;
$$;

create or replace function public.remove_archived_member(p_list_id uuid, p_profile_id uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  n int;
begin
  if not private.is_list_owner(p_list_id) then
    raise exception 'not list owner' using errcode = '42501';
  end if;
  delete from private.archived_memberships
  where list_id = p_list_id and profile_id = p_profile_id and reason = 'member_archived';
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

create or replace function public.mark_notice_seen(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  n int;
begin
  update public.account_notices set seen_at = now()
  where id = p_id and recipient_id = auth.uid() and seen_at is null;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- Verwaltung (nur Service-Role). 'purge' kommt mit Migration 028.
-- ---------------------------------------------------------------------------------------------------------------

create or replace function public.admin_delete_user(p_user_id uuid, p_mode text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if p_mode = 'archive' then
    perform private.archive_account(p_user_id);
  elsif p_mode = 'purge' then
    raise exception 'purge not available before migration 028' using errcode = '0A000';
  else
    raise exception 'mode must be archive or purge' using errcode = '22023';
  end if;
end;
$$;

revoke execute on function
  public.delete_my_account(), public.my_account_status(), public.restore_my_account(),
  public.archived_list_members(uuid), public.remove_archived_member(uuid, uuid), public.mark_notice_seen(uuid)
  from public, anon;
grant execute on function
  public.delete_my_account(), public.my_account_status(), public.restore_my_account(),
  public.archived_list_members(uuid), public.remove_archived_member(uuid, uuid), public.mark_notice_seen(uuid)
  to authenticated, service_role;

revoke execute on function public.admin_delete_user(uuid, text) from public, anon, authenticated;
grant execute on function public.admin_delete_user(uuid, text) to service_role;
