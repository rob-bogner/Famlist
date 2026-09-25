-- 011_categories_store_route.sql
--
-- Redesign „Hybrid“, Phase 6 (Kategorien verwalten):
-- Kategorien werden pro Nutzer frei anlegbar. Die Reihenfolge entspricht dem Weg durch den Laden
-- und steuert die Sortierung „Nach Kategorie“.
--  - position: Reihenfolge (0 = zuerst im Laden)
--  - icon: Schlüssel des SVG-Icons (z. B. „leaf“, „drop“, siehe CategoryIconCatalog in der App)
--  - updated_at: letzte Änderung
-- Die Tabelle war bisher leer und ungenutzt; bestehende Policies (profile_id = auth.uid()) bleiben.

ALTER TABLE categories ADD COLUMN IF NOT EXISTS position INT NOT NULL DEFAULT 0;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS icon TEXT;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_categories_profile_position ON categories (profile_id, position);
