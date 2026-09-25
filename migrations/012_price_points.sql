-- 012_price_points.sql
--
-- Redesign „Hybrid“, Phase 7 (Kassenzettel und Preise):
-- „Preise speichern“ legt je erkannter Bon-Position einen Preispunkt an (Artikel, Laden, Datum, Preis).
-- Der Preisverlauf liest sie pro Artikel (item_key = Name in Kleinbuchstaben).
--  - Preise gehören dem Nutzer (profile_id); Löschen des Profils löscht sie mit (ON DELETE CASCADE,
--    damit auch delete_my_account aus Migration 009).
--  - Der Laden steht als Text in store_name (keine eigene Tabelle nötig).
--  - Preispunkte werden nur angelegt oder gelöscht, nie geändert.

CREATE TABLE IF NOT EXISTS price_points (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    item_key     TEXT NOT NULL,
    item_name    TEXT NOT NULL,
    store_name   TEXT NOT NULL,
    purchased_at DATE NOT NULL,
    price        NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_price_points_item ON price_points (profile_id, item_key, purchased_at);

ALTER TABLE price_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "price_points_own_select" ON price_points;
CREATE POLICY "price_points_own_select" ON price_points FOR SELECT USING (profile_id = auth.uid());

DROP POLICY IF EXISTS "price_points_own_insert" ON price_points;
CREATE POLICY "price_points_own_insert" ON price_points FOR INSERT WITH CHECK (profile_id = auth.uid());

DROP POLICY IF EXISTS "price_points_own_delete" ON price_points;
CREATE POLICY "price_points_own_delete" ON price_points FOR DELETE USING (profile_id = auth.uid());
