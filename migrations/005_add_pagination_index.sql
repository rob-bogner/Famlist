-- Migration: 005_add_pagination_index.sql
-- FAM-79: Add composite index for cursor-based pagination on items.
--
-- The PageLoader sorts by (list_id, created_at ASC, id ASC) and filters with a composite cursor:
--   WHERE list_id = ? AND (created_at > X OR (created_at = X AND id > Y))
-- Without this index, every page load degrades to a full-table-scan on the items table.
--
-- The index also benefits IncrementalSync queries that filter by (list_id, updated_at).

CREATE INDEX IF NOT EXISTS items_list_created_id_idx
    ON items (list_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS items_list_updated_idx
    ON items (list_id, updated_at ASC);
