-- 015: Last-Writer-Wins auf dem Server (Audit 25.09.2026, K1/K4 Sync)
-- Vorher schrieb jede App blind per upsert/update: Die zuletzt ANKOMMENDE Änderung gewann,
-- nicht die NEUESTE. Gelöschte Artikel konnten so zurückkommen, Geräte liefen auseinander.
-- Jetzt:
-- 1. HLC-Spalten sind nie NULL (Altbestand wird aufgefüllt).
-- 2. Trigger items_lww_guard: Ein UPDATE mit älterer oder gleicher HLC wird verworfen
--    (die neuere Zeile bleibt). HLC-Zeitstempel mehr als 1 Tag in der Zukunft werden abgelehnt,
--    damit niemand mit einer manipulierten Uhr jeden Konflikt gewinnt. list_id ist unveränderbar.
-- 3. RPC upsert_items_lww(p_items): schreibt bis zu 200 Artikel in einem Aufruf und meldet je
--    Artikel „applied“ (übernommen), „stale“ (Server hat Neueres), „denied“ (kein Zugriff) oder
--    „invalid“ zurück – samt der gültigen Server-Zeile, an der sich das Gerät abgleicht.
-- Vergleich wie in HybridLogicalClock.happenedBefore: (timestamp, counter, nodeId) mit
-- Byte-Vergleich des Textes (COLLATE "C"), damit Server und App gleich entscheiden.

-- ---------------------------------------------------------------------------
-- 1. Altbestand auffüllen, danach NOT NULL
-- ---------------------------------------------------------------------------
UPDATE public.items
SET hlc_timestamp = coalesce(hlc_timestamp, (extract(epoch FROM updated_at) * 1000)::bigint),
    hlc_counter   = coalesce(hlc_counter, 0),
    hlc_node_id   = coalesce(hlc_node_id, ''),
    tombstone     = coalesce(tombstone, false)
WHERE hlc_timestamp IS NULL OR hlc_counter IS NULL OR hlc_node_id IS NULL OR tombstone IS NULL;

ALTER TABLE public.items
  ALTER COLUMN hlc_timestamp SET DEFAULT 0,
  ALTER COLUMN hlc_timestamp SET NOT NULL,
  ALTER COLUMN hlc_counter SET DEFAULT 0,
  ALTER COLUMN hlc_counter SET NOT NULL,
  ALTER COLUMN hlc_node_id SET DEFAULT '',
  ALTER COLUMN hlc_node_id SET NOT NULL,
  ALTER COLUMN tombstone SET DEFAULT false,
  ALTER COLUMN tombstone SET NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Trigger: veraltete Schreibvorgänge verwerfen
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.items_lww_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_max bigint := (extract(epoch FROM clock_timestamp()) * 1000)::bigint + 86400000;
BEGIN
  IF NEW.hlc_timestamp > v_max THEN
    RAISE EXCEPTION 'hlc_timestamp too far in the future' USING ERRCODE = '22023';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.list_id IS DISTINCT FROM OLD.list_id THEN
      RAISE EXCEPTION 'list_id is immutable' USING ERRCODE = '22023';
    END IF;
    IF (NEW.hlc_timestamp, NEW.hlc_counter, NEW.hlc_node_id COLLATE "C")
       <= (OLD.hlc_timestamp, OLD.hlc_counter, OLD.hlc_node_id COLLATE "C") THEN
      RETURN NULL;   -- älter oder gleich: Zeile unverändert lassen
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS items_lww_guard ON public.items;
-- Name beginnt mit „items_“ und feuert damit vor „trg_items_updated“ (alphabetische Reihenfolge).
CREATE TRIGGER items_lww_guard
  BEFORE INSERT OR UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.items_lww_guard();

-- ---------------------------------------------------------------------------
-- 3. RPC: Artikel mit HLC-Prüfung schreiben (SECURITY INVOKER → RLS gilt)
-- ---------------------------------------------------------------------------
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
        category, productdescription, brand, ownerpublicid, imagedata,
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
        r->>'imagedata',
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
        -- Fehlt „imagedata“ im Auftrag, bleibt das gespeicherte Foto erhalten.
        imagedata          = CASE WHEN r ? 'imagedata' THEN excluded.imagedata ELSE t.imagedata END,
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
REVOKE EXECUTE ON FUNCTION public.items_lww_guard() FROM PUBLIC, anon, authenticated;
