-- Migration: Remove units column from item_catalog
-- units does not belong in the item catalog (it's a list-level concern).
-- The app always starts with units = 1 when adding an item from the catalog.

ALTER TABLE item_catalog
    DROP COLUMN IF EXISTS units;
