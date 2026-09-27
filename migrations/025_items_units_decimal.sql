-- Migration 025: Artikelmenge als Kommazahl (z. B. 1,5 kg, 0,25 l)
--
-- items.units war integer. Neu: numeric mit höchstens 2 Nachkommastellen.
-- Ohne feste Skala, damit ganze Zahlen weiter als 2 (nicht 2.00) ausgeliefert werden.
-- upsert_items_lww liest die Menge als numeric, rundet auf 2 Stellen und entfernt Nullen am Ende
-- (trim_scale: 2 statt 2.00, 1.5 statt 1.50).
--
-- Verträglichkeit: Bestehende Werte bleiben ganze Zahlen. App-Builds, die units als Int lesen,
-- funktionieren weiter, solange keine Kommazahl gespeichert ist (Stand 27.09.2026: nur Entwickler-Geräte).

BEGIN;

ALTER TABLE public.items
  ALTER COLUMN units TYPE numeric USING units::numeric;

ALTER TABLE public.items DROP CONSTRAINT IF EXISTS items_units_range;
ALTER TABLE public.items
  ADD CONSTRAINT items_units_range CHECK (units >= 0 AND units <= 1000000 AND scale(units) <= 2);

CREATE OR REPLACE FUNCTION public.upsert_items_lww(p_items jsonb)
 RETURNS TABLE(id uuid, status text, item jsonb)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
      INSERT INTO public.items AS t (
        id, list_id, name, units, measure, price, "isChecked", is_unavailable,
        category, productdescription, brand, ownerpublicid, imagedata, image_path,
        hlc_timestamp, hlc_counter, hlc_node_id, tombstone, last_modified_by
      ) VALUES (
        v_id,
        (r->>'list_id')::uuid,
        coalesce(r->>'name', ''),
        coalesce(trim_scale(round((r->>'units')::numeric, 2)), 1),
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
        id := v_id; status := 'invalid'; item := jsonb_build_object('code', SQLSTATE, 'error', left(SQLERRM, 120));
        RETURN NEXT;
    END;
  END LOOP;
END;
$function$;

COMMIT;
