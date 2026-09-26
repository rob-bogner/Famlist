-- 017: Realtime über private Broadcast-Kanäle statt Postgres Changes (Audit 25.09.2026)
-- Warum: Postgres Changes verarbeitet alle Änderungen auf EINEM Thread und prüft für jeden
-- Abonnenten einzeln die Zeilenregeln (Supabase-Doku „Postgres Changes – scaling“). Supabase
-- empfiehlt für Skalierung Broadcast. Außerdem gingen dort bis zu 600 KB Foto-Base64 je Änderung mit.
-- Jetzt:
-- - Trigger auf items senden jede Änderung (ohne imagedata) an den privaten Kanal list:<list_id>.
-- - Lesen darf den Kanal nur, wer Zugriff auf die Liste hat. Clients dürfen NICHT in Listen-Kanäle
--   senden (die alte Regel room_members_can_write erlaubte Mitgliedern, gefälschte Artikel-Ereignisse
--   an alle zu schicken).
-- - Die alten, ungenutzten broadcast_changes-Trigger (Kanal room:<id>) entfallen.
-- - items bleibt vorerst zusätzlich in der Postgres-Changes-Publication, damit ältere App-Versionen
--   weiter funktionieren. Entfernen: Migration 018, sobald alle Geräte aktualisiert sind.

CREATE OR REPLACE FUNCTION public.try_uuid(p_text text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE WHEN p_text ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
              THEN p_text::uuid END;
$$;
REVOKE EXECUTE ON FUNCTION public.try_uuid(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.try_uuid(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Trigger: Artikeländerung → list:<list_id>, Ereignis „item_change“
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.broadcast_item_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_list uuid := coalesce(NEW.list_id, OLD.list_id);
BEGIN
  PERFORM realtime.send(
    jsonb_build_object(
      'operation', TG_OP,
      'record', CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) - 'imagedata' END,
      'old_record', CASE WHEN TG_OP = 'DELETE' THEN jsonb_build_object('id', OLD.id, 'list_id', OLD.list_id) END
    ),
    'item_change',
    'list:' || v_list::text,
    true
  );
  RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.broadcast_item_change() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS items_broadcast_trigger ON public.items;
CREATE TRIGGER items_broadcast_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_item_change();

-- Alte Raum-Trigger (room:<id>, ungenutzt, volle Zeilen inkl. Foto) entfernen.
DROP TRIGGER IF EXISTS lists_broadcast_trigger ON public.lists;
DROP TRIGGER IF EXISTS list_members_broadcast_trigger ON public.list_members;
DROP FUNCTION IF EXISTS public.broadcast_changes_trigger();

-- ---------------------------------------------------------------------------
-- Kanal-Berechtigungen (realtime.messages)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS room_members_can_read ON realtime.messages;
DROP POLICY IF EXISTS room_members_can_write ON realtime.messages;
DROP POLICY IF EXISTS list_topic_read ON realtime.messages;
CREATE POLICY list_topic_read ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    (SELECT realtime.topic()) LIKE 'list:%'
    AND public.has_list_access(public.try_uuid(split_part((SELECT realtime.topic()), ':', 2)))
  );
