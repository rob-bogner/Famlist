-- 005_add_item_is_unavailable.sql
--
-- Adds the "Nicht verfügbar" (not available in store) flag to items.
-- Created: 24.09.2026 (Hybrid-Redesign, Wisch-Aktion „Nicht verfügbar“)
--
-- Notes:
-- - MUST be applied BEFORE shipping an app build that writes is_unavailable.
--   The app sends this column in every upsert/update (ItemRow / ItemUpdatePayload).
--   Without the column PostgREST rejects those writes and the SyncEngine keeps retrying them.
-- - NOT NULL DEFAULT false keeps existing rows and older app builds (which never send the column) valid.
-- - Conflict resolution follows the existing row-level LWW via hlc_* columns; no extra metadata needed.
-- - Realtime: a publication without an explicit column list includes new columns automatically.
--   If supabase_realtime was created with a column list for items, add is_unavailable there (not verified).

ALTER TABLE items
ADD COLUMN IF NOT EXISTS is_unavailable BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN items.is_unavailable IS 'Item marked as not available in the store (swipe action); independent of isChecked';
