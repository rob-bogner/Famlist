-- 010_invite_preview.sql
--
-- Redesign „Hybrid“, Phase 5 (Einladung annehmen):
-- Vor dem Beitritt darf der Eingeladene die Liste per RLS nicht lesen. Der Screen „Einladung annehmen“
-- zeigt aber Listenname, Artikelzahl und Mitgliederzahl. Diese Funktion liefert GENAU diese drei Werte.
-- Wer die Listen-UUID kennt, kann ohnehin beitreten (Policy lm_self_insert); die Vorschau verrät nicht mehr.
-- Nur angemeldete Nutzer dürfen sie aufrufen.

CREATE OR REPLACE FUNCTION public.invite_preview(p_list_id UUID)
RETURNS TABLE (title TEXT, item_count INT, member_count INT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT l.title,
         (SELECT count(*) FROM items i WHERE i.list_id = l.id AND coalesce(i.tombstone, false) = false)::int,
         ((SELECT count(*) FROM list_members m WHERE m.list_id = l.id) + 1)::int
  FROM lists l
  WHERE l.id = p_list_id;
$$;

REVOKE ALL ON FUNCTION public.invite_preview(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.invite_preview(UUID) TO authenticated;
