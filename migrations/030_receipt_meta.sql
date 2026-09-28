-- 030_receipt_meta.sql
-- Einkaufsdaten am Kassenzettel (29.09.2026, Auftrag RECEIPT_INSIGHTS_PROMPT.md, Plan RECEIPT_INSIGHTS_PLAN.md)
--
-- 1. public.receipts.store_address: Adresse des Ladens laut Bon (Straße und Hausnummer, sonst PLZ und Ort).
-- 2. public.receipts.started_at: Einkaufsbeginn laut Liste (erstes Abhaken). Nur gesetzt, wenn plausibel.
-- 3. public.receipts.ended_at: Uhrzeit laut Bon zusammen mit dem Einkaufstag; ohne Uhrzeit auf dem Bon
--    der Zeitpunkt der Aufnahme (nur am selben Tag).
-- Die Zeilen in receipts.lines bekommen zusätzlich die optionalen Felder category, units, measure, item_id.
-- Dafür ist keine Änderung am Schema nötig; die Grenze aus 029 (500 Zeilen, 200 000 Byte) reicht weiter.
--
-- Nur neue Spalten ohne Pflichtwert: bestehende Zeilen und ältere App-Versionen bleiben unberührt.
-- Bewusst KEINE Regel „started_at < ended_at“: Ein abgelehnter Insert bliebe in der Offline-Warteschlange
-- der App hängen. Die App prüft die Plausibilität selbst.

alter table public.receipts
  add column if not exists store_address text,
  add column if not exists started_at timestamptz,
  add column if not exists ended_at timestamptz;

alter table public.receipts drop constraint if exists receipts_store_address_length;
alter table public.receipts
  add constraint receipts_store_address_length check (store_address is null or char_length(store_address) <= 200);
