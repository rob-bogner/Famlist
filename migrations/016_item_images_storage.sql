-- 016: Produktfotos in Supabase Storage statt als Base64 in der Zeile (Audit 25.09.2026)
-- Vorher: bis zu 600 KB Base64 je Artikel in items.imagedata und item_catalog.image_data.
-- Das blähte die Datenbank auf und ging bei jeder Änderung des Artikels per Realtime an alle Geräte.
-- Jetzt:
-- - Fotos liegen in privaten Buckets. Der Dateiname ist der SHA-256 des Inhalts
--   (gleiches Foto = gleiche Datei, Hochladen ist wiederholbar).
--   item-images/<list_id>/<sha256>.jpg     – lesen/schreiben: alle mit Zugriff auf die Liste
--   catalog-images/<user_id>/<sha256>.jpg  – nur der Besitzer des Artikelstamms
-- - Die Zeile trägt nur noch den Pfad (image_path). Beim Schreiben eines Pfads wird das alte
--   Base64-Feld geleert. Die alten Spalten bleiben, bis alle Geräte umgestellt sind.

ALTER TABLE public.items ADD COLUMN IF NOT EXISTS image_path text;
ALTER TABLE public.item_catalog ADD COLUMN IF NOT EXISTS image_path text;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'items_image_path_len') THEN
    ALTER TABLE public.items ADD CONSTRAINT items_image_path_len CHECK (length(image_path) <= 200);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'item_catalog_image_path_len') THEN
    ALTER TABLE public.item_catalog ADD CONSTRAINT item_catalog_image_path_len CHECK (length(image_path) <= 200);
  END IF;
END $$;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('item-images', 'item-images', false, 1048576, ARRAY['image/jpeg']),
       ('catalog-images', 'catalog-images', false, 1048576, ARRAY['image/jpeg'])
ON CONFLICT (id) DO UPDATE
  SET public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Hilfsfunktion: erster Ordner des Pfads als UUID (NULL, wenn keiner).
CREATE OR REPLACE FUNCTION public.storage_folder_uuid(p_name text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE WHEN (storage.foldername(p_name))[1] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
              THEN ((storage.foldername(p_name))[1])::uuid END;
$$;
REVOKE EXECUTE ON FUNCTION public.storage_folder_uuid(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.storage_folder_uuid(text) TO authenticated;

-- item-images: Zugriff nach Listen-Zugriff; kein Löschen durch Clients (Dateien werden geteilt).
DROP POLICY IF EXISTS item_images_read ON storage.objects;
DROP POLICY IF EXISTS item_images_insert ON storage.objects;
DROP POLICY IF EXISTS item_images_update ON storage.objects;
CREATE POLICY item_images_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'item-images' AND public.has_list_access(public.storage_folder_uuid(name)));
CREATE POLICY item_images_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'item-images' AND public.has_list_access(public.storage_folder_uuid(name)));
CREATE POLICY item_images_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'item-images' AND public.has_list_access(public.storage_folder_uuid(name)))
  WITH CHECK (bucket_id = 'item-images' AND public.has_list_access(public.storage_folder_uuid(name)));

-- catalog-images: nur der eigene Ordner.
DROP POLICY IF EXISTS catalog_images_own ON storage.objects;
CREATE POLICY catalog_images_own ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'catalog-images' AND public.storage_folder_uuid(name) = (SELECT auth.uid()))
  WITH CHECK (bucket_id = 'catalog-images' AND public.storage_folder_uuid(name) = (SELECT auth.uid()));

-- Artikelstamm: Pfad gesetzt → altes Base64 leeren.
CREATE OR REPLACE FUNCTION public.item_catalog_clear_legacy_image()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.image_path IS DISTINCT FROM OLD.image_path THEN
    NEW.image_data := NULL;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.item_catalog_clear_legacy_image() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_item_catalog_clear_legacy_image ON public.item_catalog;
CREATE TRIGGER trg_item_catalog_clear_legacy_image
  BEFORE UPDATE ON public.item_catalog
  FOR EACH ROW EXECUTE FUNCTION public.item_catalog_clear_legacy_image();

-- upsert_items_lww: Foto-Pfad (image_path) statt Base64. Fehlt der Schlüssel, bleibt der gespeicherte Pfad.
CREATE OR REPLACE FUNCTION public.upsert_items_lww(p_items jsonb)
RETURNS TABLE (id uuid, status text, item jsonb)
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = public
AS $$
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
        coalesce((r->>'units')::int, 1),
        coalesce(r->>'measure', ''),
        coalesce((r->>'price')::float8, 0),
        coalesce((r->>'isChecked')::boolean, false),
        coalesce((r->>'is_unavailable')::boolean, false),
        r->>'category',
        r->>'productdescription',
        r->>'brand',
        r->>'ownerpublicid',
        CASE WHEN r ? 'image_path' THEN NULL ELSE r->>'imagedata' END,
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
        ownerpublicid      = coalesce(t.ownerpublicid, excluded.ownerpublicid),   -- Ersteller bleibt
        -- Neuer Weg: Pfad ins Storage. Mit Pfad wird das alte Base64 geleert.
        image_path         = CASE WHEN r ? 'image_path' THEN excluded.image_path ELSE t.image_path END,
        imagedata          = CASE WHEN r ? 'image_path' THEN NULL
                                  WHEN r ? 'imagedata' THEN excluded.imagedata
                                  ELSE t.imagedata END,
        hlc_timestamp      = excluded.hlc_timestamp,
        hlc_counter        = excluded.hlc_counter,
        hlc_node_id        = excluded.hlc_node_id,
        tombstone          = excluded.tombstone,
        last_modified_by   = excluded.last_modified_by
      RETURNING t.* INTO v_row;

      IF v_row.id IS NOT NULL THEN
        status := 'applied';
      ELSE
        -- Trigger hat verworfen: Server hat eine neuere Version (oder dieselbe).
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
        id := v_id; status := 'invalid'; item := jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
        RETURN NEXT;
    END;
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.upsert_items_lww(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_items_lww(jsonb) TO authenticated;
