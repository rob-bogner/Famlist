-- 037_items_created_by.sql
-- Geteilte Liste: Wer hat den Artikel hinzugefügt? (11.10.2026, Wunsch Robert)
--
-- Die App zeigt bei Artikeln, die ein ANDERES Mitglied hinzugefügt hat, dessen Profilbild neben dem Mengen-Chip
-- (Design: ListShared / ListSharedNoImages). Bisher gab es dafür keine Spalte: ownerpublicid enthält bei neuen
-- Artikeln den Besitzer der LISTE, nicht den Hinzufügenden.
--
-- - items.created_by: Profil-ID (= auth.uid()) dessen, der die Zeile angelegt hat.
-- - Fälschungssicher per Trigger: beim Anlegen immer auth.uid() (was der Client schickt, zählt nicht),
--   beim Ändern bleibt der alte Wert. Ohne Anmeldung (Service-Rolle, Skripte) bleibt ein mitgeschickter Wert.
-- - Altbestand bleibt leer (unbekannt) → dort zeigt die App kein Profilbild.
-- - Lesen über die bestehenden Regeln für items (Spalte der bestehenden Tabelle), Realtime liefert sie mit.
-- WICHTIG: vor der neuen App-Version ausführen – die App liest die Spalte mit (SupabaseItemRow.columns).

alter table public.items add column if not exists created_by uuid;

create or replace function private.items_keep_created_by()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$function$;

revoke all on function private.items_keep_created_by() from public, anon;

drop trigger if exists trg_items_created_by on public.items;
create trigger trg_items_created_by
  before insert or update on public.items
  for each row execute function private.items_keep_created_by();
