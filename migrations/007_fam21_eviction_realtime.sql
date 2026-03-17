-- FAM-21 Bug Fix: list_members zur Realtime-Publication hinzufügen
-- Ermöglicht DELETE-Events an Clients, die ihre eigene Membership beobachten.
-- Guard gegen duplicate_object falls list_members bereits in der Publication ist.
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE list_members;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
