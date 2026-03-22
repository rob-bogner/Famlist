-- P7: FK list_members.profile_id → profiles.id (ON DELETE CASCADE)
-- Keine Waisen-Rows vorhanden (geprüft). CASCADE entfernt Membership bei Profile-Löschung.
ALTER TABLE list_members
  ADD CONSTRAINT list_members_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- P8: has_list_access(), is_list_owner(), is_list_member() als STABLE markieren.
-- Alle drei sind reine Lese-Funktionen ohne Seiteneffekte.
-- STABLE erlaubt dem Postgres-Planner Query-Level-Caching innerhalb eines Statements.

CREATE OR REPLACE FUNCTION public.has_list_access(p_list_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
AS $function$
  select public.is_list_owner(p_list_id)
         or public.is_list_member(p_list_id);
$function$;

CREATE OR REPLACE FUNCTION public.is_list_owner(p_list_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.lists l
    where l.id = p_list_id
      and l.owner_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_list_member(p_list_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.list_members m
    where m.list_id = p_list_id
      and m.profile_id = auth.uid()
  );
$function$;

-- P10: Toten HLC-Index droppen (kein Query-Pfad nutzt ihn; nur Write-Overhead).
DROP INDEX IF EXISTS idx_items_hlc;
