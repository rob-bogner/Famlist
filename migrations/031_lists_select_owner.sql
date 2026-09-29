-- 031_lists_select_owner.sql
-- Fehler (29.09.2026): Neue Listen ließen sich seit Migration 020 nicht mehr anlegen (403, 42501
-- „new row violates row-level security policy for table lists“). Letzte angelegte Liste: 25.09. 16:34 UTC.
--
-- Ursache: Die App legt eine Liste mit `insert … returning` an (PostgREST `select=*`). Postgres prüft dann
-- die neue Zeile auch gegen die Leseregel lists_select. Diese fragt private.accessible_list_ids() ab – eine
-- STABLE-Funktion, die die Tabelle lists mit dem Stand VOR dem Befehl liest. Die neue Liste ist darin noch
-- nicht enthalten, also wird die Zeile abgelehnt. Ohne `returning` klappt derselbe insert.
--
-- Reparatur: Die Leseregel prüft zusätzlich direkt an der Zeile, ob sie dem Aufrufer gehört. Das ist dieselbe
-- Bedingung wie im ersten Teil von accessible_list_ids() (Besitzer und Konto nicht archiviert) und gibt keine
-- zusätzlichen Rechte. Geprüft mit migrations/tests/031_lists_select_owner_check.sql.

drop policy if exists lists_select on public.lists;
create policy lists_select on public.lists for select to authenticated
  using ((owner_id = (select auth.uid()) and (select private.caller_active()))
         or id = any (array(select private.accessible_list_ids())));
