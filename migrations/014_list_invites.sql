-- 014: Einladungen mit Token (Audit 25.09.2026, K1/K2)
-- Vorher war die Listen-ID der Einladungsschlüssel: jeder, der sie kannte, konnte sich
-- per INSERT in list_members eintragen, für immer und auch nach dem Entfernen.
-- Jetzt:
-- - Beitritt nur über accept_list_invite(token). Der Token ist zufällig (192 Bit),
--   läuft nach 14 Tagen ab und wird widerrufen, sobald der Besitzer ein Mitglied entfernt.
-- - Clients dürfen list_members nicht mehr selbst beschreiben (nur verlassen bzw.
--   als Besitzer entfernen).
-- - „Du wurdest entfernt“ kommt als privater Broadcast an user:<id> statt über
--   Postgres Changes (DELETE-Events lassen sich dort nicht filtern und gingen an alle).

CREATE TABLE IF NOT EXISTS public.list_invites (
  token       text PRIMARY KEY,
  list_id     uuid NOT NULL REFERENCES public.lists(id) ON DELETE CASCADE,
  created_by  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL DEFAULT now() + interval '14 days',
  revoked_at  timestamptz
);
CREATE INDEX IF NOT EXISTS idx_list_invites_list ON public.list_invites (list_id);
CREATE INDEX IF NOT EXISTS idx_list_invites_creator ON public.list_invites (created_by);
ALTER TABLE public.list_invites ENABLE ROW LEVEL SECURITY;
-- Keine Policies: Zugriff ausschließlich über die RPCs unten.
REVOKE ALL ON public.list_invites FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- Einladung erzeugen (jeder mit Zugriff auf die Liste)
-- Gibt einen noch mindestens 7 Tage gültigen eigenen Token zurück, statt bei jedem
-- Öffnen des Teilen-Screens einen neuen anzulegen.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_list_invite(p_list_id uuid)
RETURNS TABLE (token text, expires_at timestamptz)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_token text;
  v_expires timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT public.has_list_access(p_list_id) THEN
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
$$;

-- ---------------------------------------------------------------------------
-- Vorschau für „Einladung annehmen“ (nur mit gültigem Token)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.invite_preview_by_token(p_token text)
RETURNS TABLE (list_id uuid, title text, item_count integer, member_count integer, inviter_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT l.id,
         l.title,
         (SELECT count(*) FROM public.items it
           WHERE it.list_id = l.id AND coalesce(it.tombstone, false) = false)::int,
         ((SELECT count(*) FROM public.list_members m WHERE m.list_id = l.id) + 1)::int,
         coalesce(nullif(p.full_name, ''), nullif(p.username, ''), p.public_id)
  FROM public.list_invites i
  JOIN public.lists l ON l.id = i.list_id
  LEFT JOIN public.profiles p ON p.id = i.created_by
  WHERE i.token = p_token
    AND i.revoked_at IS NULL
    AND i.expires_at > now()
    AND auth.uid() IS NOT NULL;
$$;

-- ---------------------------------------------------------------------------
-- Einladung annehmen. Gibt die Listen-ID zurück. Idempotent.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_list_invite(p_token text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_list uuid;
  v_owner uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT i.list_id, l.owner_id INTO v_list, v_owner
  FROM public.list_invites i
  JOIN public.lists l ON l.id = i.list_id
  WHERE i.token = p_token AND i.revoked_at IS NULL AND i.expires_at > now();

  IF v_list IS NULL THEN
    RAISE EXCEPTION 'invite invalid or expired' USING ERRCODE = 'P0002';
  END IF;

  IF v_owner <> v_uid THEN
    INSERT INTO public.list_members (list_id, profile_id, role)
    VALUES (v_list, v_uid, 'collaborator')
    ON CONFLICT (list_id, profile_id) DO NOTHING;
  END IF;

  RETURN v_list;
END;
$$;

-- ---------------------------------------------------------------------------
-- Entfernt der Besitzer ein Mitglied, werden alle offenen Einladungen der Liste
-- widerrufen (sonst könnte der Entfernte mit dem alten Link zurückkommen).
-- Außerdem erfährt der Entfernte es über seinen privaten Kanal user:<id>.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.on_list_member_removed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.profile_id IS DISTINCT FROM auth.uid() THEN
    UPDATE public.list_invites SET revoked_at = now()
    WHERE list_id = OLD.list_id AND revoked_at IS NULL;
  END IF;

  PERFORM realtime.send(
    jsonb_build_object('list_id', OLD.list_id),
    'member_removed',
    'user:' || OLD.profile_id::text,
    true
  );
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_list_member_removed ON public.list_members;
CREATE TRIGGER trg_list_member_removed
  AFTER DELETE ON public.list_members
  FOR EACH ROW EXECUTE FUNCTION public.on_list_member_removed();

-- ---------------------------------------------------------------------------
-- list_members: Clients dürfen nicht mehr selbst eintragen
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS lm_self_insert ON public.list_members;
DROP POLICY IF EXISTS list_members_owner_manage ON public.list_members;

CREATE POLICY lm_owner_delete ON public.list_members
  FOR DELETE TO authenticated
  USING (public.is_list_owner(list_id));

-- Postgres Changes für list_members abschalten (Leck: DELETE-Events ungefiltert).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables
             WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'list_members') THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.list_members;
  END IF;
END $$;

-- Privater Kanal pro Nutzer
DROP POLICY IF EXISTS user_topic_read ON realtime.messages;
CREATE POLICY user_topic_read ON realtime.messages
  FOR SELECT TO authenticated
  USING ((SELECT realtime.topic()) = 'user:' || (SELECT auth.uid())::text);

-- Alte Vorschau per Listen-ID entfernen (Listen-ID ist kein Schlüssel mehr)
DROP FUNCTION IF EXISTS public.invite_preview(uuid);

-- ---------------------------------------------------------------------------
-- Rechte
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.create_list_invite(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.invite_preview_by_token(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.accept_list_invite(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.on_list_member_removed() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_list_invite(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_preview_by_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_list_invite(text) TO authenticated;
