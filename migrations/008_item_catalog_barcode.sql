-- 008_item_catalog_barcode.sql
--
-- Redesign „Hybrid“, Phase 3 (Barcode-Scanner):
-- Eigene Artikel im Artikelstamm merken sich ihren EAN/UPC-Code. Ein erneuter Scan findet den
-- Artikel dann direkt, auch wenn er nicht im globalen Open-Food-Facts-Katalog steht.
--
-- Nur additiv: neue, nullbare Spalte + Index. Bestehende Zeilen bleiben unverändert.

ALTER TABLE item_catalog ADD COLUMN IF NOT EXISTS barcode TEXT;

CREATE INDEX IF NOT EXISTS idx_item_catalog_owner_barcode
    ON item_catalog (owner_public_id, barcode)
    WHERE barcode IS NOT NULL;
