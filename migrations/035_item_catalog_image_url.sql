-- 035_item_catalog_image_url.sql
-- Artikelstamm merkt sich die Bildadresse aus dem globalen Katalog (30.09.2026).
--
-- Wer ein Produkt aus „Weitere Produkte“ oder per Barcode hinzufügt, bekommt das Bild von dieser Adresse
-- (OpenFoodFacts). Die App lädt es sofort nach; klappt das nicht (kein Netz), steht die Adresse im Artikelstamm
-- und das Bild wird beim nächsten Hinzufügen geladen.
-- Die App schickt image_url nur mit, wenn sie gesetzt ist – ein späteres Speichern ohne Adresse löscht sie nicht.
-- RLS unverändert (Spalte der bestehenden Tabelle). WICHTIG: vor der neuen App-Version ausführen – iPhone und
-- Uhr lesen die Spalte mit.

alter table public.item_catalog add column if not exists image_url text;

alter table public.item_catalog drop constraint if exists item_catalog_image_url_https;
alter table public.item_catalog add constraint item_catalog_image_url_https
  check (image_url is null or (image_url ~ '^https://' and char_length(image_url) <= 500));
