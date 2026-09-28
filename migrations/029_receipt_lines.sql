-- 029_receipt_lines.sql
-- Kassenzettel mit seinen Artikeln (28.09.2026, Wunsch Robert: „Kassenzettel dem Einkauf zuordnen“)
--
-- 1. public.receipts.lines: die Positionen des Bons, wie sie in „Kassenzettel prüfen“ standen –
--    Bon-Text, zugeordneter Artikel (oder null), Zeilenbetrag, Preis je Stück, Stückzahl, gespeichert ja/nein.
--    JSON-Liste statt eigener Tabelle: Ein Bon wird einmal angelegt und nie geändert; die Zeilen erben so
--    dieselbe Sichtbarkeit (RLS) wie der Bon, ohne neue Regeln.
-- 2. public.price_points.receipt_id: von welchem Bon ein Preis stammt (null = von Hand eingetragen oder
--    Bon ohne Archiv-Eintrag). Bewusst OHNE Fremdschlüssel: Preise und Bon werden getrennt und offline-fest
--    gesendet (Preise zuerst, der Bon erst nach dem Foto-Upload). Ein Fremdschlüssel ließe die Preise
--    scheitern, solange der Bon noch nicht angekommen ist. Wird der Bon gelöscht, bleibt der Verweis stehen
--    und zeigt ins Leere – die App behandelt das wie „kein Bon“.
--
-- Nur neue Spalten mit Standardwerten: bestehende Zeilen und ältere App-Versionen bleiben unberührt.

alter table public.receipts
  add column if not exists lines jsonb not null default '[]'::jsonb;

alter table public.receipts drop constraint if exists receipts_lines_shape;
alter table public.receipts
  add constraint receipts_lines_shape check (
    jsonb_typeof(lines) = 'array'
    and jsonb_array_length(lines) <= 500
    and octet_length(lines::text) <= 200000
  );

alter table public.price_points
  add column if not exists receipt_id uuid;

create index if not exists idx_price_points_receipt
  on public.price_points (receipt_id) where receipt_id is not null;
