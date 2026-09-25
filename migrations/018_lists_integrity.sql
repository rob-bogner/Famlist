-- 018: Listen – eindeutige Standardliste, atomare Umstellung, Titel-Grenzen (Audit 25.09.2026)
-- Vorher:
-- - Zwei App-Pfade legten eine Standardliste an, wenn keine existierte. Liefen sie gleichzeitig
--   (z. B. erster Start auf zwei Geräten), entstanden zwei Standardlisten.
-- - „Als Standard setzen“ waren zwei getrennte Aufrufe (alle abwählen, dann eine setzen). Brach die
--   Verbindung dazwischen ab, hatte der Nutzer keine Standardliste mehr.
-- Jetzt:
-- - Höchstens eine Standardliste je Besitzer (eindeutiger Teil-Index).
-- - ensure_default_list(p_id, p_title): legt die Standardliste an, falls keine existiert (auch mit einer
--   vom Gerät vergebenen ID, für den Offline-Start), und liefert sie zurück. Wiederholbar.
-- - set_default_list(p_list_id): stellt in EINER Transaktion um.
-- - Titel 1–100 Zeichen.

CREATE UNIQUE INDEX IF NOT EXISTS lists_one_default_per_owner ON public.lists (owner_id) WHERE is_default;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lists_title_length') THEN
    ALTER TABLE public.lists ADD CONSTRAINT lists_title_length
      CHECK (char_length(btrim(title)) BETWEEN 1 AND 100);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.ensure_default_list(p_id uuid DEFAULT NULL, p_title text DEFAULT 'My List')
RETURNS SETOF public.lists
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.lists (id, owner_id, title, is_default)
  VALUES (coalesce(p_id, gen_random_uuid()), auth.uid(), coalesce(nullif(btrim(p_title), ''), 'My List'), true)
  ON CONFLICT (owner_id) WHERE is_default DO NOTHING;
  RETURN QUERY SELECT * FROM public.lists l WHERE l.owner_id = auth.uid() AND l.is_default;
END;
$$;

DROP FUNCTION IF EXISTS public.set_default_list(uuid);
CREATE FUNCTION public.set_default_list(p_list_id uuid)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.lists WHERE id = p_list_id AND owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'list not found or not owned' USING ERRCODE = 'P0002';
  END IF;
  UPDATE public.lists SET is_default = false WHERE owner_id = auth.uid() AND is_default AND id <> p_list_id;
  UPDATE public.lists SET is_default = true WHERE id = p_list_id;
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ensure_default_list(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_default_list(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_default_list(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_default_list(uuid) TO authenticated;
