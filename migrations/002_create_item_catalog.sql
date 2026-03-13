-- Migration: 002_create_item_catalog
-- Purpose: Create user-scoped item catalog table for smart search feature
-- Every item a user has ever added to any list is stored here for future lookup

CREATE TABLE IF NOT EXISTS item_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_public_id TEXT NOT NULL,
    name TEXT NOT NULL,
    name_lower TEXT GENERATED ALWAYS AS (lower(name)) STORED,
    brand TEXT,
    category TEXT,
    product_description TEXT,
    measure TEXT NOT NULL DEFAULT 'pcs',
    units INT NOT NULL DEFAULT 1,
    price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    image_data TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (owner_public_id, name_lower)
);

-- Indexes for efficient search queries
CREATE INDEX IF NOT EXISTS idx_item_catalog_owner
    ON item_catalog (owner_public_id);

CREATE INDEX IF NOT EXISTS idx_item_catalog_search
    ON item_catalog (owner_public_id, name_lower);

-- Enable Row Level Security
ALTER TABLE item_catalog ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see and manage their own catalog entries
CREATE POLICY "Users can manage own catalog entries"
    ON item_catalog
    FOR ALL
    USING (owner_public_id = auth.uid()::TEXT)
    WITH CHECK (owner_public_id = auth.uid()::TEXT);

-- Function to auto-update updated_at on row change
CREATE OR REPLACE FUNCTION update_item_catalog_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_item_catalog_updated_at
    BEFORE UPDATE ON item_catalog
    FOR EACH ROW
    EXECUTE FUNCTION update_item_catalog_updated_at();
