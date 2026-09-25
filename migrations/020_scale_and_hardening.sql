-- 020_scale_and_hardening.sql
-- Audit-Runde 2 (25.09.2026): Leistung für viele Nutzer, Grenzen gegen Missbrauch, Sync-Zeitstempel.
--
-- 1. Zugriffsregeln für lists / items / list_members: die erlaubten Listen werden EINMAL pro Abfrage
--    ermittelt (private.accessible_list_ids) statt je Zeile has_list_access aufzurufen. Vorher las
--    `select * from lists` die Listen ALLER Nutzer (Seq Scan), der Delta-Abgleich brauchte 30-mal mehr
--    Datenblöcke. Gemessen: Delta-Abgleich 5,8 ms / 231 Blöcke → 1,3 ms / 11 Blöcke, Index-Zugriff.
-- 2. search_global_products: Suche im globalen Katalog (227 000 Produkte) erst ab 3 Zeichen, Kandidaten
--    zuerst über den Trigramm-Index, dann nach Beliebtheit sortiert. Vorher lief Postgres den
--    Beliebtheits-Index entlang und prüfte jede Zeile: im Mittel 2,8 s, bis 6,3 s pro Tastendruck.
--    Gemessen: seltener Begriff 5 656 ms → 6 ms, häufiger Begriff ≤ 150 ms.
-- 3. Artikel: Längen- und Wertegrenzen; das alte Base64-Feld imagedata wird nicht mehr angenommen.
-- 4. updated_at = tatsächliche Schreibzeit (clock_timestamp statt Transaktionsbeginn). Sonst konnte
--    der Delta-Abgleich Zeilen einer langen Transaktion überspringen.
-- 5. Wer eine Liste selbst verlässt, verliert auch seine Einladungslinks.
-- 6. Neue Tabellen/Funktionen bekommen nicht mehr automatisch Rechte für anon/PUBLIC; TRUNCATE entzogen.

-- ---------------------------------------------------------------------------------------------
-- 1. Erlaubte Listen einmal pro Abfrage
-- ---------------------------------------------------------------------------------------------
create or replace function private.accessible_list_ids()
returns setof uuid
language sql
stable security definer
set search_path to 'public'
as $function$
  select l.id from public.lists l where l.owner_id = (select auth.uid())
  union
  select m.list_id from public.list_members m where m.profile_id = (select auth.uid());
$function$;

revoke all on function private.accessible_list_ids() from public, anon;
grant execute on function private.accessible_list_ids() to authenticated;

drop policy if exists lists_select on public.lists;
create policy lists_select on public.lists for select to authenticated
  using (id = any (array(select private.accessible_list_ids())));

drop policy if exists items_access on public.items;
create policy items_access on public.items for all to authenticated
  using (list_id = any (array(select private.accessible_list_ids())))
  with check (list_id = any (array(select private.accessible_list_ids())));

drop policy if exists list_members_select on public.list_members;
create policy list_members_select on public.list_members for select to authenticated
  using (profile_id = (select auth.uid()) or list_id = any (array(select private.accessible_list_ids())));

-- ---------------------------------------------------------------------------------------------
-- 2. Globale Produktsuche
-- ---------------------------------------------------------------------------------------------
create or replace function public.search_global_products(p_query text)
returns table(code text, name text, brand text, category text, measure text, image_url text, scans_n integer)
language plpgsql
stable
security invoker
set search_path to 'public'
as $function$
DECLARE
  v_query text := lower(btrim(coalesce(p_query, '')));
  v_pattern text;
BEGIN
  IF char_length(v_query) < 3 OR char_length(v_query) > 60 THEN
    RETURN;
  END IF;
  -- % und _ sind in LIKE Platzhalter → als normale Zeichen suchen
  v_pattern := '%' || replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  -- Muster als Literal (EXECUTE): Postgres plant jede Suche mit dem echten Wert und nimmt sicher den
  -- Trigramm-Index. Höchstens 300 Kandidaten, davon die 5 beliebtesten.
  RETURN QUERY EXECUTE format($q$
    WITH hits AS MATERIALIZED (
      SELECT g.code, g.name, g.brand, g.category, g.measure, g.image_url, g.scans_n, g.name_lower
      FROM public.global_product_catalog g
      WHERE g.name_lower LIKE %L
      LIMIT 300
    )
    SELECT h.code, h.name, h.brand, h.category, h.measure, h.image_url, h.scans_n
    FROM hits h
    ORDER BY h.scans_n DESC NULLS LAST, h.name_lower
    LIMIT 5
  $q$, v_pattern);
END;
$function$;

revoke all on function public.search_global_products(text) from public, anon;
grant execute on function public.search_global_products(text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- 3. Artikel: Grenzen und kein neues Base64-Foto
-- ---------------------------------------------------------------------------------------------
alter table public.items
  add constraint items_name_len        check (char_length(name) <= 200),
  add constraint items_brand_len       check (brand is null or char_length(brand) <= 100),
  add constraint items_category_len    check (category is null or char_length(category) <= 100),
  add constraint items_description_len check (productdescription is null or char_length(productdescription) <= 500),
  add constraint items_measure_len     check (char_length(measure) <= 30),
  add constraint items_meta_len        check (char_length(coalesce(last_modified_by, '')) <= 100
                                              and char_length(coalesce(ownerpublicid, '')) <= 100
                                              and char_length(hlc_node_id) <= 100),
  add constraint items_units_range     check (units between 0 and 1000000),
  add constraint items_price_range     check (price >= 0 and price < 1000000);

create or replace function public.upsert_items_lww(p_items jsonb)
returns table(id uuid, status text, item jsonb)
language plpgsql
set search_path to 'public'
as $function$
#variable_conflict use_column
DECLARE
  r jsonb;
  v_id uuid;
  v_row public.items;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) > 200 THEN
    RAISE EXCEPTION 'p_items must be a JSON array with at most 200 entries' USING ERRCODE = '22023';
  END IF;

  FOR r IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_id := NULL;
    v_row := NULL;
    BEGIN
      v_id := (r->>'id')::uuid;

      -- imagedata (altes Base64-Foto) wird nicht mehr angenommen: neue Zeilen ohne, bestehende behalten
      -- ihr altes Foto, bis ein Storage-Pfad kommt.
      INSERT INTO public.items AS t (
        id, list_id, name, units, measure, price, "isChecked", is_unavailable,
        category, productdescription, brand, ownerpublicid, imagedata, image_path,
        hlc_timestamp, hlc_counter, hlc_node_id, tombstone, last_modified_by
      ) VALUES (
        v_id,
        (r->>'list_id')::uuid,
        coalesce(r->>'name', ''),
        coalesce((r->>'units')::int, 1),
        coalesce(r->>'measure', ''),
        coalesce((r->>'price')::float8, 0),
        coalesce((r->>'isChecked')::boolean, false),
        coalesce((r->>'is_unavailable')::boolean, false),
        r->>'category',
        r->>'productdescription',
        r->>'brand',
        r->>'ownerpublicid',
        NULL,
        r->>'image_path',
        (r->>'hlc_timestamp')::bigint,
        coalesce((r->>'hlc_counter')::int, 0),
        coalesce(r->>'hlc_node_id', ''),
        coalesce((r->>'tombstone')::boolean, false),
        r->>'last_modified_by'
      )
      ON CONFLICT ON CONSTRAINT items_pkey DO UPDATE SET
        name               = excluded.name,
        units              = excluded.units,
        measure            = excluded.measure,
        price              = excluded.price,
        "isChecked"        = excluded."isChecked",
        is_unavailable     = excluded.is_unavailable,
        category           = excluded.category,
        productdescription = excluded.productdescription,
        brand              = excluded.brand,
        ownerpublicid      = coalesce(t.ownerpublicid, excluded.ownerpublicid),
        image_path         = CASE WHEN r ? 'image_path' THEN excluded.image_path ELSE t.image_path END,
        imagedata          = CASE WHEN r ? 'image_path' THEN NULL ELSE t.imagedata END,
        hlc_timestamp      = excluded.hlc_timestamp,
        hlc_counter        = excluded.hlc_counter,
        hlc_node_id        = excluded.hlc_node_id,
        tombstone          = excluded.tombstone,
        last_modified_by   = excluded.last_modified_by
      RETURNING t.* INTO v_row;

      IF v_row.id IS NOT NULL THEN
        status := 'applied';
      ELSE
        SELECT * INTO v_row FROM public.items WHERE items.id = v_id;
        status := CASE WHEN v_row.id IS NULL THEN 'denied' ELSE 'stale' END;
      END IF;

      id := v_id;
      item := CASE WHEN v_row.id IS NULL THEN NULL ELSE to_jsonb(v_row) - 'imagedata' END;
      RETURN NEXT;
    EXCEPTION
      WHEN insufficient_privilege THEN
        id := v_id; status := 'denied'; item := NULL; RETURN NEXT;
      WHEN OTHERS THEN
        -- nur Fehlercode und kurze Meldung, keine internen Details
        id := v_id; status := 'invalid'; item := jsonb_build_object('code', SQLSTATE, 'error', left(SQLERRM, 120));
        RETURN NEXT;
    END;
  END LOOP;
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 4. updated_at = tatsächliche Schreibzeit
-- ---------------------------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
BEGIN
  NEW.updated_at = clock_timestamp();
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 5. Mitglied entfernt / ausgetreten: Einladungen widerrufen
-- ---------------------------------------------------------------------------------------------
create or replace function public.on_list_member_removed()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF OLD.profile_id IS DISTINCT FROM auth.uid() THEN
    -- Besitzer entfernt jemanden: alle offenen Links der Liste ungültig machen
    UPDATE public.list_invites SET revoked_at = now()
    WHERE list_id = OLD.list_id AND revoked_at IS NULL;
  ELSE
    -- Mitglied tritt selbst aus: seine eigenen Links ungültig machen
    UPDATE public.list_invites SET revoked_at = now()
    WHERE list_id = OLD.list_id AND created_by = OLD.profile_id AND revoked_at IS NULL;
  END IF;

  PERFORM realtime.send(
    jsonb_build_object('list_id', OLD.list_id),
    'member_removed',
    'user:' || OLD.profile_id::text,
    true
  );
  RETURN OLD;
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 6. Standardrechte für neue Objekte, TRUNCATE entziehen
-- ---------------------------------------------------------------------------------------------
alter default privileges in schema public revoke execute on functions from public, anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke truncate on tables from authenticated;
revoke truncate on all tables in schema public from anon, authenticated;
