-- 033_category_color.sql
-- Kategorie-Farbe (30.09.2026): Jede Kategorie kann eine von 36 Farben haben (Kategorie bearbeiten → Farbe).
-- Gespeichert wird der Hex-Wert (#RRGGBB). NULL = Standardfarbe, die die App aus dem Namen ableitet
-- (z. B. „Obst & Gemüse“ grün). RLS bleibt unverändert (Spalte der bestehenden Tabelle).
-- WICHTIG: vor dem Start der neuen App-Version ausführen – iPhone und Watch lesen die Spalte mit.

ALTER TABLE categories ADD COLUMN IF NOT EXISTS color TEXT;

ALTER TABLE categories DROP CONSTRAINT IF EXISTS categories_color_hex;
ALTER TABLE categories ADD CONSTRAINT categories_color_hex CHECK (color IS NULL OR color ~ '^#[0-9A-Fa-f]{6}$');
