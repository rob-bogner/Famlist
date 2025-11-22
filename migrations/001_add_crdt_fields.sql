-- Migration: Add CRDT fields to items table for distributed conflict resolution
-- Created: 22.11.2025
-- Purpose: Enable Hybrid Logical Clock (HLC) based CRDT sync between devices

-- Add HLC timestamp (milliseconds since epoch)
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS hlc_timestamp BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT;

-- Add HLC logical counter for same-timestamp disambiguation
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS hlc_counter INTEGER NOT NULL DEFAULT 0;

-- Add HLC node identifier (device/user UUID)
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS hlc_node_id TEXT NOT NULL DEFAULT '';

-- Add tombstone flag for CRDT deletions
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS tombstone BOOLEAN NOT NULL DEFAULT false;

-- Add last modifier tracking
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS last_modified_by TEXT;

-- Create composite index for HLC-based queries and conflict resolution
CREATE INDEX IF NOT EXISTS idx_items_hlc ON items(hlc_timestamp, hlc_counter, hlc_node_id);

-- Create index for tombstone queries (filtering deleted items)
CREATE INDEX IF NOT EXISTS idx_items_tombstone ON items(tombstone) WHERE tombstone = true;

-- Update existing rows to have valid HLC data
-- This ensures backward compatibility for items created before CRDT migration
UPDATE items 
SET hlc_timestamp = (EXTRACT(EPOCH FROM created_at) * 1000)::BIGINT,
    hlc_counter = 0,
    hlc_node_id = COALESCE(ownerpublicid, ''),
    last_modified_by = ownerpublicid
WHERE hlc_node_id = '';

-- Add comment for documentation
COMMENT ON COLUMN items.hlc_timestamp IS 'Hybrid Logical Clock timestamp in milliseconds for causal ordering';
COMMENT ON COLUMN items.hlc_counter IS 'HLC logical counter for disambiguating concurrent events';
COMMENT ON COLUMN items.hlc_node_id IS 'Device/user identifier that created this version';
COMMENT ON COLUMN items.tombstone IS 'CRDT tombstone flag indicating soft deletion';
COMMENT ON COLUMN items.last_modified_by IS 'Identifier of the user/device that last modified this item';

