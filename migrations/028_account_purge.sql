-- 028_account_purge.sql
-- Endgültiges Löschen archivierter Konten nach 60 Tagen – inklusive Fotos (Plan: design-handoff/ACCOUNT_ARCHIVE_PLAN.md §4).
--
-- Warum pg_net: Fotos lassen sich nur über die Storage-API löschen (storage.protect_delete blockiert DELETE auf
-- storage.objects; die Datei bliebe sonst verwaist). Die Storage-API erreicht nur eine Edge Function. pg_cron kann
-- eine Edge Function nur per HTTP aufrufen, und HTTP aus Postgres geht nur mit pg_net.
--
-- Ablauf: Cron (täglich 03:30) → Edge Function account-purge → je fälligem Konto: Pfade holen
-- (account_storage_paths) → Dateien per Storage-API löschen → account_purge_rows (verweigert, solange noch
-- Dateien da sind). Die Function löscht nur, was ohnehin fällig ist; der öffentliche Anon-Schlüssel genügt.
-- „Jetzt endgültig löschen“ (App) und admin_delete_user(…, 'purge') setzen purge_after = now() und stoßen denselben
-- Lauf sofort an.

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------------------------------------------
-- Hilfsfunktionen für die Edge Function (nur Service-Role)
-- ---------------------------------------------------------------------------------------------------------------

create or replace function public.account_purge_due(p_limit int default 20)
returns setof uuid
language sql
stable
security definer
set search_path to ''
as $$
  select a.user_id from private.account_archive a
  where a.purge_after <= now()
  order by a.purge_after
  limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

create or replace function public.account_storage_paths(p_user uuid)
returns table(bucket text, name text)
language sql
stable
security definer
set search_path to ''
as $$
  select o.bucket_id, o.name
  from storage.objects o
  where (o.bucket_id in ('avatars', 'catalog-images')
         and (storage.foldername(o.name))[1] = p_user::text)
     or (o.bucket_id in ('item-images', 'receipt-images')
         and (storage.foldername(o.name))[1] in (select l.id::text from public.lists l where l.owner_id = p_user));
$$;

create or replace function public.account_is_archived(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select private.is_archived(p_user);
$$;

-- Macht ein archiviertes Konto sofort fällig („Jetzt endgültig löschen“). Nicht archiviert → false.
create or replace function public.account_mark_due(p_user uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  n int;
begin
  update private.account_archive set purge_after = least(purge_after, now()) where user_id = p_user;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- Löscht alle Zeilen eines fälligen Kontos. Verweigert, solange noch Fotos im Storage liegen.
create or replace function public.account_purge_rows(p_user uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not exists (select 1 from private.account_archive a where a.user_id = p_user and a.purge_after <= now()) then
    return false;
  end if;
  if exists (select 1 from public.account_storage_paths(p_user)) then
    raise exception 'storage not empty for %', p_user using errcode = '55000';
  end if;

  delete from private.archived_memberships
  where profile_id = p_user or list_id in (select l.id from public.lists l where l.owner_id = p_user);
  delete from public.items where list_id in (select l.id from public.lists l where l.owner_id = p_user);
  delete from public.list_members where list_id in (select l.id from public.lists l where l.owner_id = p_user);
  delete from public.lists where owner_id = p_user;                -- receipts, list_invites: FK cascade
  delete from public.list_members where profile_id = p_user;
  delete from public.item_catalog where owner_public_id = p_user::text;
  delete from public.categories where profile_id = p_user;
  delete from public.account_notices where recipient_id = p_user or subject_id = p_user;
  delete from public.profiles where id = p_user;                   -- price_points, list_invites: FK cascade
  delete from auth.users where id = p_user;                        -- account_archive, identities, sessions: cascade
  return true;
end;
$$;

revoke execute on function
  public.account_purge_due(int), public.account_storage_paths(uuid), public.account_is_archived(uuid),
  public.account_mark_due(uuid), public.account_purge_rows(uuid)
  from public, anon, authenticated;
grant execute on function
  public.account_purge_due(int), public.account_storage_paths(uuid), public.account_is_archived(uuid),
  public.account_mark_due(uuid), public.account_purge_rows(uuid)
  to service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- Aufruf der Edge Function aus Postgres (Cron und admin_delete_user)
-- ---------------------------------------------------------------------------------------------------------------

-- Der Anon-Schlüssel ist öffentlich (steht auch in der App); er reicht, weil account-purge nur Fälliges löscht.
create or replace function private.invoke_account_purge(p_user uuid default null)
returns bigint
language sql
security definer
set search_path to ''
as $$
  select net.http_post(
    url     := 'https://mbfztpbwfktiduemqqfe.supabase.co/functions/v1/account-purge',
    body    := case when p_user is null then '{}'::jsonb else jsonb_build_object('user_id', p_user) end,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1iZnp0cGJ3Zmt0aWR1ZW1xcWZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY2NTQyNjcsImV4cCI6MjA3MjIzMDI2N30.CjNmk9oJ2nBoaVjVWnbIcDqGMSJS0uN1hpkqwKtA6xE'),
    timeout_milliseconds := 120000);
$$;

revoke execute on function private.invoke_account_purge(uuid) from public, anon, authenticated;

create or replace function public.admin_delete_user(p_user_id uuid, p_mode text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if p_user_id is null then
    raise exception 'user required' using errcode = '22004';
  end if;
  if p_mode = 'archive' then
    perform private.archive_account(p_user_id);
  elsif p_mode = 'purge' then
    perform private.archive_account(p_user_id);          -- tut nichts, wenn schon archiviert
    perform public.account_mark_due(p_user_id);
    perform private.invoke_account_purge(p_user_id);
  else
    raise exception 'mode must be archive or purge' using errcode = '22023';
  end if;
end;
$$;

revoke execute on function public.admin_delete_user(uuid, text) from public, anon, authenticated;
grant execute on function public.admin_delete_user(uuid, text) to service_role;

select cron.schedule('account-purge', '30 3 * * *', $$select private.invoke_account_purge()$$);
