-- 022_catalog_usage.sql
-- „Oft gekauft“ für die Apple Watch (26.09.2026, design-handoff/WATCH_PLAN.md §4)
--
-- Der Artikelstamm (item_catalog) zählt, wie oft ein Artikel zu einer Liste hinzugefügt wurde:
--   use_count     – Zahl der Hinzufügungen (beginnt bei 0; es gibt keine historischen Daten)
--   last_used_at  – Zeitpunkt der letzten Hinzufügung (auf dem Gerät gemessen, nie in der Zukunft)
-- „Oft gekauft“ = die ersten Einträge nach use_count absteigend, dann last_used_at absteigend.
--
-- Gezählt wird nur über die RPC catalog_note_use, nie per UPDATE aus der App:
--   - atomar (use_count = use_count + n) → zwei Geräte überschreiben sich keine Zählungen;
--   - nur eigene Einträge (RLS item_catalog_own aus Migration 019 und Filter auf auth.uid());
--   - Namen ohne Eintrag im eigenen Artikelstamm werden ignoriert.
-- Die App sendet den Auftrag über die Offline-Warteschlange des Artikelstamms, IMMER nach dem Speichern
-- des Eintrags. Offline gesammelte Aufträge tragen ihren eigenen Zeitpunkt; ein älterer Zeitpunkt setzt
-- last_used_at nie zurück.

-- ---------------------------------------------------------------------------------------------
-- 1. Spalten
-- ---------------------------------------------------------------------------------------------
alter table public.item_catalog
  add column if not exists use_count    integer not null default 0,
  add column if not exists last_used_at timestamptz;

alter table public.item_catalog drop constraint if exists item_catalog_use_count_range;
alter table public.item_catalog add constraint item_catalog_use_count_range check (use_count >= 0);

-- Sortierung „Oft gekauft“ je Nutzer.
create index if not exists idx_item_catalog_owner_usage
  on public.item_catalog (owner_public_id, use_count desc, last_used_at desc nulls last);

-- ---------------------------------------------------------------------------------------------
-- 2. RPC: Hinzufügungen zählen
-- ---------------------------------------------------------------------------------------------
-- p_names:   Artikelnamen (Groß/klein egal, gleicher Name mehrfach = mehrfach gezählt), höchstens 200.
-- p_used_at: Zeitpunkt der Hinzufügung; NULL oder Zukunft → now().
-- Rückgabe:  Zahl der geänderten Einträge.
create or replace function public.catalog_note_use(p_names text[], p_used_at timestamptz default null)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid   text := (select auth.uid())::text;
  v_at    timestamptz := least(coalesce(p_used_at, now()), now());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'catalog_note_use: nicht angemeldet' using errcode = '28000';
  end if;
  if p_names is null or cardinality(p_names) = 0 then
    return 0;
  end if;
  if cardinality(p_names) > 200 then
    raise exception 'catalog_note_use: höchstens 200 Namen je Aufruf' using errcode = '22023';
  end if;

  with uses as (
    select lower(n) as name_lower, count(*)::integer as n_uses
      from unnest(p_names) as n
     where n is not null and length(n) between 1 and 200
     group by lower(n)
  )
  update public.item_catalog c
     set use_count    = c.use_count + uses.n_uses,
         last_used_at = greatest(coalesce(c.last_used_at, v_at), v_at)
    from uses
   where c.owner_public_id = v_uid
     and c.name_lower = uses.name_lower;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.catalog_note_use(text[], timestamptz) from public, anon;
grant execute on function public.catalog_note_use(text[], timestamptz) to authenticated;
