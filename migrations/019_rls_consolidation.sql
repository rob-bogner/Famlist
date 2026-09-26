-- 019_rls_consolidation.sql
-- Audit 25.09.2026, Paket P8 (Datenbankpflege und Leistung)
--
-- 1. Hilfsfunktionen für Zugriffsrechte (has_list_access, is_list_owner, is_list_member, shares_list_with)
--    ziehen in das nicht veröffentlichte Schema "private". Vorher konnte jeder angemeldete Nutzer sie über
--    /rest/v1/rpc/… aufrufen und damit fremde Listen-IDs abfragen („gibt es diese Liste, bin ich drin?“).
--    Richtlinien in public, storage und realtime verweisen intern über die Objekt-ID und bleiben gültig.
-- 2. profile_display_name wird entfernt (von der App nicht genutzt).
-- 3. Richtlinien zusammengelegt: je Tabelle und Aktion genau eine Regel, nur für die Rolle "authenticated",
--    auth.uid() als (select auth.uid()) – wird einmal pro Abfrage statt einmal pro Zeile berechnet.
-- 4. list_invites bekommt eine ausdrückliche Sperrregel (Zugriff nur über die Einladungs-Funktionen).
-- 5. Doppelte und überflüssige Indizes entfernt, fehlende ergänzt (Fremdschlüssel favorite_list_id,
--    Nachladen geänderter Artikel je Liste nach updated_at).
-- 6. pg_trgm aus public in das Schema extensions verschoben.

-- ---------------------------------------------------------------------------------------------
-- 1. Hilfsfunktionen nach private
-- ---------------------------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.is_list_owner(uuid)   set schema private;
alter function public.is_list_member(uuid)  set schema private;
alter function public.has_list_access(uuid) set schema private;
alter function public.shares_list_with(uuid) set schema private;

create or replace function private.has_list_access(p_list_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select private.is_list_owner(p_list_id)
         or private.is_list_member(p_list_id);
$function$;

revoke all on function private.is_list_owner(uuid), private.is_list_member(uuid),
                       private.has_list_access(uuid), private.shares_list_with(uuid) from public, anon;
grant execute on function private.is_list_owner(uuid), private.is_list_member(uuid),
                          private.has_list_access(uuid), private.shares_list_with(uuid) to authenticated;

create or replace function public.create_list_invite(p_list_id uuid)
returns table(token text, expires_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_uid uuid := auth.uid();
  v_token text;
  v_expires timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT private.has_list_access(p_list_id) THEN
    RAISE EXCEPTION 'no access to list' USING ERRCODE = '42501';
  END IF;

  SELECT i.token, i.expires_at INTO v_token, v_expires
  FROM public.list_invites i
  WHERE i.list_id = p_list_id AND i.created_by = v_uid
    AND i.revoked_at IS NULL AND i.expires_at > now() + interval '7 days'
  ORDER BY i.expires_at DESC
  LIMIT 1;

  IF v_token IS NULL THEN
    v_token := translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/=', '-_');
    INSERT INTO public.list_invites (token, list_id, created_by)
    VALUES (v_token, p_list_id, v_uid)
    RETURNING list_invites.expires_at INTO v_expires;
  END IF;

  RETURN QUERY SELECT v_token, v_expires;
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 2. Ungenutzte Funktion entfernen
-- ---------------------------------------------------------------------------------------------
drop function if exists public.profile_display_name(text);

-- ---------------------------------------------------------------------------------------------
-- 3. Richtlinien zusammenlegen
-- ---------------------------------------------------------------------------------------------
-- categories: eigene Kategorien + gemeinsame Standardkategorien (profile_id IS NULL) lesen
drop policy if exists categories_cud_own_only on public.categories;
drop policy if exists categories_owner_crud   on public.categories;
drop policy if exists categories_public_read  on public.categories;
create policy categories_select on public.categories for select to authenticated
  using (profile_id is null or profile_id = (select auth.uid()));
create policy categories_insert on public.categories for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy categories_update on public.categories for update to authenticated
  using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
create policy categories_delete on public.categories for delete to authenticated
  using (profile_id = (select auth.uid()));

-- global_product_catalog: nur lesen, nur angemeldet
drop policy if exists "Authenticated users can read global catalog" on public.global_product_catalog;
create policy global_catalog_select on public.global_product_catalog for select to authenticated
  using (true);

-- item_catalog: eigener Artikelstamm
drop policy if exists "Users can manage own catalog entries" on public.item_catalog;
create policy item_catalog_own on public.item_catalog for all to authenticated
  using (owner_public_id = (select auth.uid())::text)
  with check (owner_public_id = (select auth.uid())::text);

-- items: Zugriff = Besitzer oder Mitglied der Liste (has_list_access deckt beides ab)
drop policy if exists "Users can select items from their lists" on public.items;
drop policy if exists items_member_crud   on public.items;
drop policy if exists items_owner_crud    on public.items;
drop policy if exists items_select_access on public.items;
create policy items_access on public.items for all to authenticated
  using (private.has_list_access(list_id))
  with check (private.has_list_access(list_id));

-- list_members: lesen mit Listenzugriff; austreten selbst oder entfernen als Besitzer.
-- Hinzufügen nur über accept_list_invite (SECURITY DEFINER), daher keine INSERT-Regel.
drop policy if exists lm_list_members_can_select on public.list_members;
drop policy if exists lm_self_read     on public.list_members;
drop policy if exists lm_self_delete   on public.list_members;
drop policy if exists lm_owner_delete  on public.list_members;
create policy list_members_select on public.list_members for select to authenticated
  using (profile_id = (select auth.uid()) or private.has_list_access(list_id));
create policy list_members_delete on public.list_members for delete to authenticated
  using (profile_id = (select auth.uid()) or private.is_list_owner(list_id));

-- lists: lesen mit Zugriff, schreiben nur als Besitzer
drop policy if exists list_update_owner   on public.lists;
drop policy if exists lists_owner_crud    on public.lists;
drop policy if exists lists_select_access on public.lists;
create policy lists_select on public.lists for select to authenticated
  using (owner_id = (select auth.uid()) or private.has_list_access(id));
create policy lists_insert on public.lists for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy lists_update on public.lists for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy lists_delete on public.lists for delete to authenticated
  using (owner_id = (select auth.uid()));

-- price_points: nur eigene Preise
drop policy if exists price_points_own_delete on public.price_points;
drop policy if exists price_points_own_insert on public.price_points;
drop policy if exists price_points_own_select on public.price_points;
create policy price_points_select on public.price_points for select to authenticated
  using (profile_id = (select auth.uid()));
create policy price_points_insert on public.price_points for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy price_points_delete on public.price_points for delete to authenticated
  using (profile_id = (select auth.uid()));

-- profiles: eigenes Profil voll, Profile von Mitgliedern gemeinsamer Listen nur lesen
drop policy if exists profiles_comember_read on public.profiles;
drop policy if exists profiles_own_all       on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.shares_list_with(id));
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy profiles_delete on public.profiles for delete to authenticated
  using (id = (select auth.uid()));

-- ---------------------------------------------------------------------------------------------
-- 4. list_invites: direkter Zugriff ausdrücklich gesperrt
-- ---------------------------------------------------------------------------------------------
drop policy if exists list_invites_no_direct_access on public.list_invites;
create policy list_invites_no_direct_access on public.list_invites for all to authenticated
  using (false) with check (false);

-- ---------------------------------------------------------------------------------------------
-- 5. Indizes
-- ---------------------------------------------------------------------------------------------
-- doppelt oder vom Primärschlüssel / einem breiteren Index abgedeckt
drop index if exists public.items_list_idx;                 -- = idx_items_list_id
drop index if exists public.lists_owner_idx;                -- = idx_lists_owner_id
drop index if exists public.idx_profiles_id;                -- = Primärschlüssel
drop index if exists public.list_members_profile_idx;       -- Anfang von idx_list_members_profile_list
drop index if exists public.idx_list_members_list_id;       -- Anfang des Primärschlüssels (list_id, profile_id)
drop index if exists public.idx_categories_profile_id;      -- Anfang von idx_categories_profile_position
drop index if exists public.idx_item_catalog_search;        -- = Unique-Schlüssel (owner_public_id, name_lower)
drop index if exists public.idx_item_catalog_owner;         -- Anfang desselben Unique-Schlüssels
-- ohne Nutzen: Ja/Nein-Spalten und ungenutzte Volltextsuche
drop index if exists public.items_checked_idx;
drop index if exists public.lists_is_default_idx;           -- lists_one_default_per_owner deckt die Abfrage ab
drop index if exists public.items_name_trgm;                -- App sucht nie serverseitig in items.name

-- Nachladen geänderter Artikel: where list_id = ? and updated_at > ? order by updated_at, id
create index if not exists idx_items_list_updated on public.items (list_id, updated_at, id);
drop index if exists public.idx_items_list_id;              -- Anfang von idx_items_list_updated
-- Fremdschlüssel ohne Index (Löschen einer Liste prüft profiles.favorite_list_id)
create index if not exists idx_profiles_favorite_list on public.profiles (favorite_list_id);

-- ---------------------------------------------------------------------------------------------
-- 6. pg_trgm aus public entfernen
-- ---------------------------------------------------------------------------------------------
alter extension pg_trgm set schema extensions;
