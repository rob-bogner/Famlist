-- 009_account_sharing_favorites.sql
--
-- Redesign „Hybrid“, Phase 4 (Listen, Teilen, Konto):
--  1. profiles.favorite_list_id  – Favorit „öffnet beim App-Start“ (pro Nutzer, nicht pro Liste).
--     lists.is_default gehört der Liste und damit allen Mitgliedern; ein Mitglied darf es per RLS nicht ändern.
--  2. profiles.notify_shared_lists / notify_invites – Schalter in den Einstellungen.
--  3. Policy lm_self_delete – Mitglieder dürfen eine geteilte Liste selbst verlassen.
--  4. RPC delete_my_account() – löscht alle eigenen Daten und das Auth-Konto (App-Store-Pflicht).
--  5. Storage-Bucket avatars – Profilfotos. Der Bucket existierte bereits (privat, leer, seit 07.09.2025)
--     und bleibt privat: lesen dürfen angemeldete Nutzer (signierte Links), schreiben nur im eigenen Ordner.
-- Nur additiv bzw. neue Objekte; bestehende Zeilen bleiben unverändert.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS favorite_list_id UUID REFERENCES lists(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_shared_lists BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notify_invites BOOLEAN NOT NULL DEFAULT true;

DROP POLICY IF EXISTS "lm_self_delete" ON list_members;
CREATE POLICY "lm_self_delete" ON list_members
  FOR DELETE USING (profile_id = auth.uid());

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Eigene Listen samt Artikeln und Mitgliedschaften anderer
  DELETE FROM items WHERE list_id IN (SELECT id FROM lists WHERE owner_id = uid);
  DELETE FROM list_members WHERE list_id IN (SELECT id FROM lists WHERE owner_id = uid);
  DELETE FROM lists WHERE owner_id = uid;

  -- Aus geteilten Listen austreten
  DELETE FROM list_members WHERE profile_id = uid;

  -- Artikelstamm und Kategorien
  DELETE FROM item_catalog WHERE owner_public_id = uid::text;
  DELETE FROM categories WHERE profile_id = uid;

  -- Profilfotos löscht die App vorher über die Storage-API (direktes DELETE auf storage.objects ist gesperrt).

  -- Profil und Auth-Konto
  DELETE FROM profiles WHERE id = uid;
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "avatars_authenticated_read" ON storage.objects;
CREATE POLICY "avatars_authenticated_read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_own_insert" ON storage.objects;
CREATE POLICY "avatars_own_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avatars_own_update" ON storage.objects;
CREATE POLICY "avatars_own_update" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avatars_own_delete" ON storage.objects;
CREATE POLICY "avatars_own_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
