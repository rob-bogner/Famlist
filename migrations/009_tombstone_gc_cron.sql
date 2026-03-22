-- P11: Tombstone Garbage Collection via pg_cron
-- Löscht tombstoned Items die seit 30+ Tagen nicht mehr aktualisiert wurden.
-- Läuft täglich um 03:00 UTC.

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- GC-Funktion: Purge alte Tombstones
CREATE OR REPLACE FUNCTION public.gc_tombstones()
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM items
  WHERE tombstone = true
    AND updated_at < now() - interval '30 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- Cron-Job: täglich 03:00 UTC
SELECT cron.schedule(
  'tombstone-gc',
  '0 3 * * *',
  'SELECT public.gc_tombstones()'
);
