-- 039_items_created_by_on_return.sql
-- Geteilte Liste: „hinzugefügt von“ auch setzen, wenn ein Artikel ZURÜCK auf die Liste kommt (11.10.2026).
--
-- Befund am 11.10.2026: Sofie fügte Artikel aus der Zwischenablage hinzu, bei Robert erschien kein Profilbild.
-- Migration 037 setzt items.created_by nur beim Anlegen einer Zeile. Die App verwendet Artikelzeilen aber wieder:
-- Die ID hängt an Liste + Name, Löschen setzt nur tombstone. Wer „Sahne“ erneut hinzufügt, ändert die alte
-- Zeile – created_by blieb dadurch leer (0 von 146 Zeilen hatten einen Wert).
--
-- Regel (Entscheidung Robert, 11.10.2026): created_by wird auf den Schreibenden gesetzt, wenn
--   1. die Zeile neu angelegt wird (wie 037),
--   2. ein gelöschter Artikel wieder hinzugefügt wird (tombstone true → false),
--   3. ein abgehakter Artikel wieder offen wird (isChecked true → false).
-- Bewusste Nebenwirkung von 3: Der Server kann „erneut hinzugefügt“ nicht von „Haken entfernt“ unterscheiden.
-- Wer „Zurücksetzen“ tippt oder einen Haken wieder entfernt, gilt danach als die Person, die den Artikel
-- hinzugefügt hat.
--
-- Unverändert: Was der Client als created_by schickt, zählt nicht. Ohne Anmeldung (Service-Rolle, Skripte)
-- bleibt der Wert bei Änderungen stehen. Ein veralteter Schreibversuch erreicht diesen Trigger nicht
-- (items_lww_guard läuft vorher und verwirft ihn).
-- Die App spiegelt die Regel lokal (SwiftDataItemStore.writeLocal), weil sie die Antwort auf die eigene
-- Änderung nicht übernimmt (gleiche HLC).
-- Prüfung: migrations/tests/039_items_created_by_on_return_check.sql

create or replace function private.items_keep_created_by()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  elsif auth.uid() is not null
        and not coalesce(new.tombstone, false)
        and (coalesce(old.tombstone, false)
             or (coalesce(old."isChecked", false) and not coalesce(new."isChecked", false))) then
    new.created_by := auth.uid();                 -- Artikel kommt zurück auf die Liste
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$function$;

revoke all on function private.items_keep_created_by() from public, anon;
