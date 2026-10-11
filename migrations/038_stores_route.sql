-- 038_stores_route.sql
-- Märkte & Einkaufsroute (11.10.2026, Wunsch Robert; Design-Auftrag: design-handoff/STORE_ROUTE_DESIGN_PROMPT.md)
--
-- Die App speichert Supermärkte mit Standort und lernt je Markt die Reihenfolge der Kategorien
-- (die „Route“). Im Markt sortiert „Nach Kategorie“ die Liste nach dieser Route.
--
--   public.stores       – ein gespeicherter Markt: Name, Koordinaten, Umkreis. Gehört einem Konto.
--   public.store_trips  – ein Einkauf in einem Markt: die Kategorienamen in der Reihenfolge des Abhakens.
--
-- Die Route wird NICHT gespeichert. Die App berechnet sie aus den letzten Einkäufen eines Marktes.
-- Dadurch überschreibt kein Mitglied die Route eines anderen: Jeder Einkauf ist eine eigene Zeile.
--
-- Entscheidungen von Robert (11.10.2026):
-- - Ein Markt gehört zum Konto und gilt in allen Listen dieses Kontos.
-- - Wer eine Liste mit dem Besitzer teilt, sieht dessen Märkte (samt Koordinaten) und darf Einkäufe
--   dazuschreiben. Ändern und Löschen darf nur der Besitzer.
-- - Die Route besteht nur aus Kategorien (items.category ist der Kategoriename als Text).
--
-- Regeln:
-- - stores: „letzter Schreiber gewinnt“ über die HLC wie bei items (Migration 015). Gelöscht wird über
--   tombstone, damit andere Geräte und Mitglieder das Löschen mitbekommen. Kein DELETE für die App.
-- - „Route zurücksetzen“ setzt stores.route_reset_at. Einkäufe davor zählt die App nicht mehr.
-- - store_trips: Nur das Gerät, das den Einkauf angelegt hat, schreibt ihn fort (während des Einkaufs
--   kommen Kategorien dazu). Ein älterer Stand (kleineres ended_at) wird verworfen.
-- - Konto archivieren (027): Mitgliedschaften verschwinden, damit auch die Sicht auf fremde Märkte.
--   Das archivierte Konto sieht seine eigenen Märkte bis zum Wiederherstellen nicht.
-- - Konto endgültig löschen (028): stores hängt an profiles (on delete cascade), store_trips an stores.
--   Einkäufe in fremden Märkten bleiben, profile_id wird NULL. account_purge_rows bleibt unverändert.
-- - Kein Realtime: Die App lädt Märkte und Einkäufe, wenn sie in den Vordergrund kommt.

-- ---------------------------------------------------------------------------------------------
-- 1. Tabellen
-- ---------------------------------------------------------------------------------------------
create table if not exists public.stores (
  id             uuid primary key,
  owner_id       uuid not null references public.profiles(id) on delete cascade,
  name           text not null,
  latitude       double precision not null,
  longitude      double precision not null,
  radius_m       integer not null default 150,
  route_reset_at timestamptz,
  hlc_timestamp  bigint not null default 0,
  hlc_counter    integer not null default 0,
  hlc_node_id    text not null default '',
  tombstone      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint stores_name_len   check (char_length(name) between 1 and 100),
  constraint stores_latitude   check (latitude between -90 and 90),
  constraint stores_longitude  check (longitude between -180 and 180),
  constraint stores_radius     check (radius_m between 30 and 1000),
  constraint stores_node_len   check (char_length(hlc_node_id) <= 100)
);

-- Sichtbare Märkte je Besitzer; zugleich Index für den Fremdschlüssel (Konto löschen).
create index if not exists idx_stores_owner on public.stores (owner_id);

create table if not exists public.store_trips (
  id          uuid primary key,
  store_id    uuid not null references public.stores(id) on delete cascade,
  profile_id  uuid references public.profiles(id) on delete set null,
  categories  text[] not null,
  started_at  timestamptz not null,
  ended_at    timestamptz not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- Eine Route braucht mindestens zwei Kategorien. Je Name höchstens 100 Zeichen (wie items_category_len).
  constraint store_trips_category_count check (cardinality(categories) between 2 and 60),
  constraint store_trips_category_len   check (char_length(array_to_string(categories, '')) <= 6000),
  constraint store_trips_time_order     check (ended_at >= started_at),
  constraint store_trips_duration       check (ended_at - started_at <= interval '12 hours')
);

-- Die letzten Einkäufe eines Marktes: where store_id = ? order by ended_at desc limit n
create index if not exists idx_store_trips_store_ended on public.store_trips (store_id, ended_at desc);
create index if not exists idx_store_trips_profile on public.store_trips (profile_id);   -- Fremdschlüssel

-- ---------------------------------------------------------------------------------------------
-- 2. Wächter: veraltete Schreibvorgänge verwerfen, feste Spalten, Obergrenzen
-- ---------------------------------------------------------------------------------------------
-- Vergleich wie items_lww_guard (015): (timestamp, counter, nodeId) mit Byte-Vergleich des Textes.
create or replace function private.stores_lww_guard()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  v_max bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint + 86400000;
begin
  if new.hlc_timestamp > v_max then
    raise exception 'hlc_timestamp too far in the future' using errcode = '22023';
  end if;
  if tg_op = 'INSERT' then
    -- Ein upsert feuert diesen Zweig auch für vorhandene Zeilen; die Obergrenze gilt nur für neue.
    if not exists (select 1 from public.stores s where s.id = new.id)
       and (select count(*) from public.stores s where s.owner_id = new.owner_id and not s.tombstone) >= 100 then
      raise exception 'too many stores' using errcode = '54000';
    end if;
  else
    if new.owner_id is distinct from old.owner_id then
      raise exception 'owner_id is immutable' using errcode = '22023';
    end if;
    if (new.hlc_timestamp, new.hlc_counter, new.hlc_node_id collate "C")
       <= (old.hlc_timestamp, old.hlc_counter, old.hlc_node_id collate "C") then
      return null;   -- älter oder gleich: Zeile unverändert lassen
    end if;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$function$;

create or replace function private.store_trips_guard()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if new.ended_at > clock_timestamp() + interval '1 day' then
    raise exception 'ended_at too far in the future' using errcode = '22023';
  end if;
  if tg_op = 'INSERT' then
    -- Höchstens 50 neue Einkäufe je Konto in 24 Stunden (ein upsert einer vorhandenen Zeile zählt nicht).
    if not exists (select 1 from public.store_trips t where t.id = new.id)
       and (select count(*) from public.store_trips t
            where t.profile_id = new.profile_id and t.created_at > now() - interval '1 day') >= 50 then
      raise exception 'too many trips' using errcode = '54000';
    end if;
  else
    if new.store_id is distinct from old.store_id or new.profile_id is distinct from old.profile_id then
      raise exception 'store_id and profile_id are immutable' using errcode = '22023';
    end if;
    if new.ended_at < old.ended_at then
      return null;   -- älterer Stand desselben Einkaufs: Zeile unverändert lassen
    end if;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$function$;

revoke all on function private.stores_lww_guard(), private.store_trips_guard() from public, anon;

-- Die Wächter heißen „store…“ und feuern damit vor „trg_…“ (alphabetische Reihenfolge).
drop trigger if exists stores_lww_guard on public.stores;
create trigger stores_lww_guard
  before insert or update on public.stores
  for each row execute function private.stores_lww_guard();

drop trigger if exists store_trips_guard on public.store_trips;
create trigger store_trips_guard
  before insert or update on public.store_trips
  for each row execute function private.store_trips_guard();

-- updated_at = tatsächliche Schreibzeit (set_updated_at aus 020).
drop trigger if exists trg_stores_updated on public.stores;
create trigger trg_stores_updated
  before update on public.stores
  for each row execute function public.set_updated_at();

drop trigger if exists trg_store_trips_updated on public.store_trips;
create trigger trg_store_trips_updated
  before update on public.store_trips
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------------------------
-- 3. Zugriff: wessen Märkte sehe ich?
-- ---------------------------------------------------------------------------------------------
-- Ich selbst (wenn nicht archiviert) und alle, mit denen ich eine Liste teile. Wird wie
-- accessible_list_ids (020) EINMAL pro Abfrage berechnet, nicht je Zeile.
create or replace function private.visible_store_owner_ids()
returns setof uuid
language sql
stable security definer
set search_path to 'public'
as $function$
  select (select auth.uid()) where (select private.caller_active())
  union
  select l.owner_id from public.lists l
  where l.id in (select private.accessible_list_ids())
  union
  select m.profile_id from public.list_members m
  where m.list_id in (select private.accessible_list_ids());
$function$;

create or replace function private.visible_store_ids()
returns setof uuid
language sql
stable security definer
set search_path to 'public'
as $function$
  select s.id from public.stores s
  where s.owner_id in (select private.visible_store_owner_ids());
$function$;

revoke all on function private.visible_store_owner_ids(), private.visible_store_ids() from public, anon;
grant execute on function private.visible_store_owner_ids(), private.visible_store_ids() to authenticated;

alter table public.stores enable row level security;
alter table public.store_trips enable row level security;

-- Nur angemeldete Nutzer; kein DELETE (stores: tombstone, store_trips: route_reset_at).
revoke all on public.stores, public.store_trips from public, anon, authenticated;
grant select, insert, update on public.stores, public.store_trips to authenticated;

drop policy if exists stores_select on public.stores;
drop policy if exists stores_insert on public.stores;
drop policy if exists stores_update on public.stores;
create policy stores_select on public.stores for select to authenticated
  using (owner_id = any (array(select private.visible_store_owner_ids())));
create policy stores_insert on public.stores for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select private.caller_active()));
create policy stores_update on public.stores for update to authenticated
  using (owner_id = (select auth.uid()) and (select private.caller_active()))
  with check (owner_id = (select auth.uid()));

drop policy if exists store_trips_select on public.store_trips;
drop policy if exists store_trips_insert on public.store_trips;
drop policy if exists store_trips_update on public.store_trips;
create policy store_trips_select on public.store_trips for select to authenticated
  using (store_id = any (array(select private.visible_store_ids())));
create policy store_trips_insert on public.store_trips for insert to authenticated
  with check (profile_id = (select auth.uid())
              and store_id = any (array(select private.visible_store_ids())));
create policy store_trips_update on public.store_trips for update to authenticated
  using (profile_id = (select auth.uid())
         and store_id = any (array(select private.visible_store_ids())))
  with check (profile_id = (select auth.uid()));
