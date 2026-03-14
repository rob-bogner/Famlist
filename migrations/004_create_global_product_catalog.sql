-- 004_create_global_product_catalog.sql
--
-- Creates the global OpenFoodFacts product catalog table for DACH products.
-- Enables fast trigram search on product names across ~500k–800k entries.
--
-- Notes:
-- - No UNIQUE(name_lower): same product name can appear under different barcodes (different pack sizes).
-- - No owner_public_id: global table without user ownership.
-- - RLS restricts reads to authenticated users only (no write access via client).

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS global_product_catalog (
    code       TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    name_lower TEXT GENERATED ALWAYS AS (lower(name)) STORED,
    brand      TEXT,
    category   TEXT,
    measure    TEXT,
    image_url  TEXT,
    scans_n    INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- GIN-Trigram-Index für ILIKE '%query%' bei 500k+ Zeilen
CREATE INDEX IF NOT EXISTS idx_gpc_name_lower_trgm
    ON global_product_catalog USING GIN (name_lower gin_trgm_ops);

-- Popularity index so most-scanned products sort first
CREATE INDEX IF NOT EXISTS idx_gpc_scans
    ON global_product_catalog (scans_n DESC);

ALTER TABLE global_product_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read global catalog"
    ON global_product_catalog FOR SELECT
    USING (auth.role() = 'authenticated');
