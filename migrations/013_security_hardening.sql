-- 013: Sicherheits-Härtung (Audit 25.09.2026)
-- 1. profiles: nicht mehr öffentlich lesbar. Lesen dürfen nur der Nutzer selbst und
--    Personen, die mit ihm mindestens eine Liste teilen.
-- 2. Hilfs-RPCs für die zwei Stellen, die bisher fremde Profile gelesen haben
--    (Benutzername frei? / Anzeigename des Einladenden).
-- 3. public_id eindeutig und nach dem ersten Setzen unveränderbar.
-- 4. Storage-Bucket avatars: kein anonymes Hochladen/Lesen, Größen- und Typlimit.
-- 5. SECURITY-DEFINER-Funktionen nicht mehr für anon/PUBLIC ausführbar.

-- ---------------------------------------------------------------------------
-- 1. Hilfsfunktion: teilt der angemeldete Nutzer eine Liste mit p_profile?
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.shares_list_with(p_profile uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH mine AS (
    SELECT l.id AS list_id FROM public.lists l WHERE l.owner_id = (SELECT auth.uid())
    UNION
    SELECT m.list_id FROM public.list_members m WHERE m.profile_id = (SELECT auth.uid())
  )
  SELECT EXISTS (
    SELECT 1 FROM mine
    WHERE EXISTS (SELECT 1 FROM public.lists l WHERE l.id = mine.list_id AND l.owner_id = p_profile)
       OR EXISTS (SELECT 1 FROM public.list_members m WHERE m.list_id = mine.list_id AND m.profile_id = p_profile)
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. profiles-Policies neu (doppelte entfernt, auth.uid() einmal pro Abfrage)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;
DROP POLICY IF EXISTS profiles_own_crud ON public.profiles;

CREATE POLICY profiles_own_all ON public.profiles
  FOR ALL TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY profiles_comember_read ON public.profiles
  FOR SELECT TO authenticated
  USING (public.shares_list_with(id));

-- ---------------------------------------------------------------------------
-- 3. RPCs statt direkter Lesezugriffe auf fremde Profile
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_username_available(p_username text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE lower(p.username) = lower(trim(p_username))
      AND p.id <> (SELECT auth.uid())
  );
$$;

-- Nur Anzeigename, keine weiteren Profildaten.
CREATE OR REPLACE FUNCTION public.profile_display_name(p_public_id text)
RETURNS TABLE (public_id text, username text, full_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.public_id, p.username, p.full_name
  FROM public.profiles p
  WHERE p.public_id = p_public_id
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- 4. public_id eindeutig und unveränderbar; Benutzername eindeutig ohne Groß/Klein
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS profiles_public_id_key ON public.profiles (public_id);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_key ON public.profiles (lower(username));

CREATE OR REPLACE FUNCTION public.protect_profile_public_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.public_id IS NOT NULL AND NEW.public_id IS DISTINCT FROM OLD.public_id THEN
    RAISE EXCEPTION 'public_id is immutable' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_public_id_immutable ON public.profiles;
CREATE TRIGGER trg_profiles_public_id_immutable
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_public_id();

-- ---------------------------------------------------------------------------
-- 5. Storage-Bucket avatars
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can upload an avatar." ON storage.objects;
DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS avatars_authenticated_read ON storage.objects;

CREATE POLICY avatars_own_or_comember_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (
        (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        AND public.shares_list_with(((storage.foldername(name))[1])::uuid)
      )
    )
  );

UPDATE storage.buckets
SET file_size_limit = 2097152,               -- 2 MB
    allowed_mime_types = ARRAY['image/jpeg']
WHERE id = 'avatars';

-- ---------------------------------------------------------------------------
-- 6. Ausführungsrechte
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.gc_tombstones() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.has_list_access(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_list_member(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_list_owner(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.shares_list_with(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_username_available(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.profile_display_name(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.broadcast_changes_trigger() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_item_catalog_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.protect_profile_public_id() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.has_list_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_list_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_list_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shares_list_with(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_username_available(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.profile_display_name(text) TO authenticated;
