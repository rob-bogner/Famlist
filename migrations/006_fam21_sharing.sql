-- FAM-21: List Sharing — fehlende RLS-Policies
-- Alle anderen Policies (has_list_access, items_member_crud, lists_select_access etc.)
-- sind bereits vorhanden. Nur diese zwei fehlen.

-- 1. Nutzer kann sich selbst als Member eintragen (Invite-Accept-Flow)
DROP POLICY IF EXISTS "lm_self_insert" ON list_members;
CREATE POLICY "lm_self_insert" ON list_members
  FOR INSERT WITH CHECK (profile_id = auth.uid());

-- 2. Alle Listenmitglieder sehen Co-Member (für MembersView)
-- has_list_access ist SECURITY DEFINER → keine RLS-Rekursionsgefahr.
DROP POLICY IF EXISTS "lm_list_members_can_select" ON list_members;
CREATE POLICY "lm_list_members_can_select" ON list_members
  FOR SELECT USING (has_list_access(list_id));
