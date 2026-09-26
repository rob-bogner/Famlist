# Kassenzettel-Archiv – Übergabe (Stand 26.09.2026)

Entscheidung: Bon-Fotos werden **in der App (Archiv)** gespeichert – Famlist + Supabase Storage.

## Design (Wahrheitsquelle, pixelgenau umsetzen)

| Screen | Datei in `Design/html/` |
|---|---|
| Einstellungen mit neuem Abschnitt „Kassenzettel“ | `Settings.dc.html` |
| Kassenzettel-Archiv (Liste) | `ReceiptArchive.dc.html` / `ReceiptArchiveDark.dc.html` |
| Kassenzettel-Detail | `ReceiptDetail.dc.html` / `ReceiptDetailDark.dc.html` |

Aktualisiert, zur Kontrolle gegen den Code (bereits umgesetzt): `Hybrid.dc.html` (Artikelkarte),
`ReceiptCapture.dc.html`, `ReceiptReview.dc.html`, `ReceiptReviewMissing*.dc.html`.

### Einstellungen → Abschnitt „Kassenzettel“ (zwischen „Liste“ und „Benachrichtigungen“)
- Schalter **„Fotos der Bons speichern“**, Unterzeile „In Famlist, sichtbar für alle in der Liste“. Standard: an.
- Zeile **„Gespeicherte Kassenzettel“**, Unterzeile „<n> Bons · <Größe>“, Chevron → Archiv.
- Das Einstellungs-Sheet wird dadurch länger → Inhalt muss scrollen („Konto“ liegt unter der Falz).

### Archiv (Sheet 790, Zurück → Einstellungen, ✕ schließt)
- Unterzeile: „<n> Bons · <Größe> · für alle in der Liste sichtbar“.
- Filterchips nach Laden: „Alle“ + je Laden (aktiver Chip in CTA-Farbe).
- Gruppen nach Monat („September 2026“), je Gruppe eine Karte mit Zeilen (Trennlinie `k.line`):
  Mini-Bon 46 × 62 (bei mehreren Fotos Zähler-Badge), Laden (Outfit 17/600), „TT.MM.JJJJ · <Listenname>“,
  „<n> Positionen“ (DM 12, sub), rechts Summe (Outfit 16/600) und Avatar-Initiale 22 der Person, die gescannt hat.
- Tippen → Detail.

### Detail (Sheet 790, Zurück → Archiv, Titel = Laden)
- Unterzeile „TT.MM.JJJJ · <Listenname> · gescannt von <Name>“.
- Foto-Fläche 452 hoch (Radius 22, field-Hintergrund): Seitenzähler „1 / 2“ oben links, Vollbild-Knopf oben rechts,
  Punkte unten; Wischen blättert durch die Fotos. Vollbild mit Zoom.
- Summenkarte (Hero-Verlauf): „<n> Positionen · <m> Preise gespeichert“, „Summe laut Bon“, Betrag Outfit 26.
- Unten: „Teilen“ (Share Sheet mit den Fotos) und „Löschen“ (danger-soft).

## Entscheidungen
1. **Schalter aus** → Bon-Fotos werden gar nicht gespeichert (weder lokal noch Server). Preise werden weiter gespeichert.
2. **Sichtbarkeit** → alle Mitglieder der Liste, auf der eingekauft wurde (wie Artikelfotos, `has_list_access`).
3. **Löschen** → löscht Fotos und Archiv-Eintrag; die Preispunkte im Preisverlauf bleiben.

## Datenmodell (Vorschlag, Muster wie 012_price_points + 016_item_images_storage)
- Tabelle `receipts`: `id uuid pk`, `list_id uuid` (FK lists, on delete cascade), `created_by uuid` (profiles),
  `store_name text`, `purchased_at date`, `total numeric(10,2)`, `line_count int`, `saved_price_count int`,
  `photo_paths text[]` (max. 10), `bytes int`, `created_at timestamptz default now()`.
  RLS: select/insert für `has_list_access(list_id)`; delete für Ersteller **oder** Listen-Besitzer.
- Bucket `receipt-images` (privat, image/jpeg, ≤ 1,5 MB je Foto): Pfad `<list_id>/<receipt_id>/<n>.jpg`,
  Regeln über `storage_folder_uuid(name)` + `has_list_access` (lesen/schreiben), löschen wie Tabelle.
- Fotos vor dem Hochladen verkleinern (lange Kante ~2000 px, JPEG ~0,7) – Bons bleiben lesbar.

## Ablauf in der App
- Beim „Preise speichern“ in „Kassenzettel prüfen“ (nur wenn Schalter an): Archiv-Eintrag + Fotos anlegen.
- **Offline-First**: Eintrag und Fotos zuerst lokal (Warteschlange wie `PriceBook`, Fotos als Dateien im
  App-Container), dann hochladen; bei fehlendem Netz später (Reconnect wie `PriceBook.reconnect`).
- Archiv zeigt lokal ausstehende Bons sofort (mit dezentem „wird hochgeladen“-Hinweis), Serverdaten danach.
- Fotos im Archiv lazy laden + Cache (wie `ItemImagePrefetcher`), Mini-Bon = verkleinertes erstes Foto.

## Nicht vergessen
- Neue Dateien in `project.pbxproj` eintragen, eine Type je Datei, `#Preview` Hell + Dunkel.
- UserLog nur in ViewModels (z. B. „🧾 Kassenzettel gespeichert“, „🧾 Kassenzettel gelöscht“).
- Tests: Warteschlange offline → online, Schalter aus speichert nichts, Löschen behält Preispunkte, RLS-Pfad.
- Migration als `migrations/021_receipts_archive.sql`.
