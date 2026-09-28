# One-Shot-Prompt: Einkaufsdaten am Kassenzettel + Auswertung (Ausgaben, Verbrauch)

```
Baue für Famlist „Einkaufsdaten & Auswertung“: Jeder gespeicherte Kassenzettel bekommt Metadaten (Ort, Datum,
Uhrzeit, Dauer, Wert, Artikel mit Anzahl, Einzelpreis und Kategorie), und aus allen Bons entsteht eine Auswertung
mit den Reitern „Ausgaben“ und „Verbrauch“. Das Design ist von Robert freigegeben (28.09.2026, siehe „Design“).
NICHT Teil dieses Auftrags: Nährwerte je Artikel und Auswertung „Ernährung“ (siehe „Ausdrücklich weglassen“).

## Lies zuerst
1. claude.md / CLAUDE.md (Projektregeln, Offline-First, Hybrid-Designregeln, UserLog nur in ViewModels,
   eine Type je Datei, Datei-Kopfkommentar, #Preview Hell + Dunkel).
2. design-handoff/SPEC.md (§2 Zeilen „Einkaufsdaten & Auswertung“, §3 Punkt 13, §4 Designregeln, §5).
3. design-handoff/KASSENZETTEL_ARCHIV.md (bestehendes Archiv, Datenmodell, Offline-Warteschlange).
4. Design: design-handoff/Design/html/ReceiptArchiveInsights, ReceiptDetailMeta, InsightSpend, InsightUsage
   (je .dc.html + Dark.dc.html) und die PNGs in design-handoff/Design/png/. Zum Vergleich der heutige Stand:
   ReceiptArchive, ReceiptDetail, PriceHistory.
5. App-Code:
   - Features/Receipts/Models: ArchivedReceipt, ReceiptLine, ReceiptArchiveDraft, ParsedReceipt, PricePoint
   - Features/Receipts/Services: ReceiptParser (detectStore, detectDate), ReceiptItemMatcher, PriceStatistics
   - Features/Receipts/ViewModels: ReceiptArchive (+Sync, +Photos), ReceiptArchiveViewModel, ReceiptFlowViewModel,
     PriceBook, PriceHistoryViewModel
   - Features/Receipts/Views: ReceiptArchiveSheet, ReceiptArchiveRow, ReceiptDetailSheet, ReceiptPhotoPager,
     PriceHistorySheet
   - Repositories/Implementations/SupabaseReceiptsRepository.swift (Spaltenliste, lines-JSON)
   - Features/ShoppingList/Models/ActiveListSheet.swift (+ baseSheet), ShoppingListView+Receipts.swift,
     ShoppingListView+Sheets.swift, ListViewModel+ShoppingCompletion.swift, ListViewModel+ItemStatus.swift
   - Features/Categories (CategoryStore, CategoryResolver, CategoryIconCatalog)
6. migrations/ (zuletzt 029_receipt_lines.sql) und migrations/tests/.

## Entscheidungen von Robert (28.09.2026) – nicht erneut fragen
- Einstieg: Karte oben im Kassenzettel-Archiv (ReceiptArchiveInsights). Kein eigener Menüpunkt.
- Die Auswertung ist ein Sheet 790 mit Reitern „Ausgaben“ · „Verbrauch“ und Monatswechsel.
- Umfang der Daten = dieselben Bons, die das Archiv zeigt (Liste, alle Mitglieder).
- Nährwerte und „Ernährung“ kommen später mit eigenem Auftrag (Quellen dann Open Food Facts + BLS 4.0).
  Datenmodell jetzt so anlegen, dass Nährwerte später ohne Umbau dazukommen (nichts davon jetzt bauen).
- Watch: keine Änderung (die Watch kennt keine Kassenzettel). Das im Plan kurz bestätigen.

## Ausdrücklich weglassen
- ReceiptItemNutrition und InsightNutrition (Entwürfe, liegen auf der Canvas-Seite „Archiv“) NICHT bauen.
  Die vier freigegebenen Boards enthalten schon keine Nährwerte mehr und zeigen nur „Ausgaben“ · „Verbrauch“.
- Tipp auf eine Artikelzeile im Detail öffnet den bestehenden Preisverlauf des zugeordneten Artikels
  (wie .itemPriceHistory / .priceHistory; Zurück → Detail). Zeilen ohne zugeordneten Artikel sind nicht tippbar.

## Design (freigegeben; Boards in design-handoff/Design/html/)
Artboard 390 × 844, 1 CSS-px = 1 pt, Light UND Dark. Alle Knöpfe im Glas-Stil (wie FAB, GlassCircleButton /
Glas-Pillen). Nur Original-SVG-Icons aus den Boards (keine SF Symbols), Outfit für Titel/Zahlen, DM Sans für Text,
Akzent aus AccentScale, Farben aus SheetTheme (k.*). Maße aus dem HTML übernehmen, nicht schätzen.

1. ReceiptArchiveInsights – Archiv wie heute; unter der Unterzeile „<n> Bons · <Größe> …“ (Abstand 14) eine
   Karte im Hero-Verlauf (heroBg, Radius 20, Padding 14/16, Schatten wie CTA): Icon-Kachel 44 (Radius 14, weiß 20 %)
   mit Balken-Icon, „Auswertung <Monat>“ (13, weiß 85 %), „<Summe> · <n> Einkäufe“ (Outfit 22/600),
   „Ausgaben und Verbrauch“ (12), Chevron rechts. Monat = aktueller Monat; gibt es darin keinen Bon, der letzte
   Monat mit Bons. Ohne Bons keine Karte. Tipp → Auswertung (Reiter „Ausgaben“, dieser Monat).
2. ReceiptDetailMeta – ersetzt das heutige Detail (Sheet 790, Zurück → Archiv, ✕, Titel = Laden):
   - Unterzeile „<Listenname> · gescannt von <Name>“ (Datum steht jetzt in den Kacheln).
   - Raster 3 × 2 Kacheln (Abstand 8, field-Hintergrund, Radius 16, Padding 10/12): Label 11/600 sub mit Icon 13
     in accentText, Wert 15/600 (einzeilig, … kürzen), Unterzeile 11 sub.
     Ort: Laden + Straße · Datum: „Do, 24.09.“ + Jahr · Uhrzeit: Start + „bis <Ende>“ · Dauer: „23 min“ +
     „laut Liste“ · Artikel: „<Positionen> · <Stück> Stück“ + „<n> Mehrfachkauf/-käufe“ · Wert: Summe +
     „Ø <Betrag> je Stück“. Unbekannte Werte: „–“ ohne Unterzeile.
   - Segment „Artikel“ · „Bon-Foto“ (wie Board). „Bon-Foto“ zeigt den bestehenden Foto-Pager mit Vollbild.
     Ohne Fotos (Schalter aus) kein Segment, nur die Artikel.
   - Artikel-Karte: Zeile = Kategorie-Kachel 38 (Radius 12, Kategoriefarbe 12 % / Dark 18 %, Kategorie-Icon aus
     CategoryIconCatalog in der Kategoriefarbe), Name 15/600 (zugeordneter Artikel, sonst Bon-Text),
     „<Anzahl> × <Einheit> · je <Einzelpreis>“ 12 sub, Kategorie 12/600 in Kategoriefarbe, rechts Betrag
     Outfit 16/600. Trennlinie k.line. Ohne Kategorie: „Ohne Kategorie“, Farbe/Icon „Sonstiges“.
   - Unten „Teilen“ / „Löschen“ wie heute. Liste scrollt, unten weicher Auslauf wie im Board.
3. InsightSpend – Sheet 790, Titel „Auswertung“, ✕ (zurück ins Archiv), Segment, Monatswechsel (Glas-Knöpfe 36,
   „September 2026“ Outfit 18/600; „weiter“ gesperrt im aktuellen Monat, „zurück“ gesperrt vor dem ersten Bon):
   - Hero „Ausgegeben im <Monat>“, Summe Outfit 34, Chips: „↑/↓ <x> % ggü. <Vormonat>“ (ohne Vormonat weglassen),
     „<n> Einkäufe“, „Ø <Betrag>“.
   - „Letzte 6 Monate“ + rechts „Ø <Schnitt> €“: Säulen je Monat (gewählter Monat in Akzent, übrige segBg,
     Radius 10), Betrag über der Säule, Monatskürzel darunter, gestrichelte Linie beim Schnitt der 6 Monate.
     Monate ohne Bons zählen als 0 und fließen nicht in den Schnitt ein.
   - „Nach Kategorie“: gestapelter Balken 12 hoch + Zeilen (Kachel 30, Name, Anteil %, Betrag). Höchstens 6
     Kategorien nach Betrag, Rest + nicht zugeordnete Zeilen + Differenz „Summe laut Bon − Σ Zeilen“ (Pfand,
     Rabatte) als „Sonstiges“, damit die Summe exakt der Monatssumme entspricht.
   - „Nach Laden“: je Laden „<n> × · Ø <Betrag>“, Summe, Balken relativ zum größten Laden (Akzent).
4. InsightUsage – gleicher Kopf, Reiter „Verbrauch“:
   - Suchfeld „Produkt suchen“ (filtert die Liste, Tastatur-Handling wie in anderen Sheets).
   - Hero „<Produkt> im <Monat>“: das Produkt mit der größten Menge (Stückzahl) im Monat; Wert als Menge
     („14 Liter“), Chips „<x> pro Woche“, „↑/↓ <Δ> ggü. <Vormonat>“, Kosten.
   - „Am meisten gekauft“ + „Menge · Verlauf 6 Monate“: Zeilen mit Kachel 36, Name, Kosten, Mini-Verlauf 64 × 28
     (Linie in Kategoriefarbe, Punkt am Ende), rechts Menge Outfit 16/600 + Δ zum Vormonat (11, sub, Pfeil;
     neutral – keine Wertung durch Farbe). Sortierung nach Häufigkeit (Anzahl Käufe), dann Kosten.
   - Tipp auf eine Zeile → bestehender Preisverlauf des Produkts (Zurück → Auswertung).
5. Kategoriefarben (hell / dunkel), vergeben nach Rang in der Auswertung, in Detail und Verbrauch nach derselben
   Zuordnung (stabil je Kategorie-Name, z. B. Rang über alle Bons der Liste):
   #3FA66B/#5BC98A, #4F86E8/#7AA6F5, #D9534F/#F07C78, #8466E8/#A58CF5, #D99A2B/#F0B654, #E0679E/#F08DB9;
   „Sonstiges“ #93A5A8/#6F8588. Als Tokens anlegen (z. B. InsightPalette), nicht im View hart codieren.
6. Leere Zustände (nicht gestaltet → so umsetzen, nichts Neues erfinden): Monat ohne Bons → Hero mit „0,00 €“ und
   Chip „Keine Einkäufe“, Abschnitte darunter ausblenden. Verbrauch ohne Treffer bei der Suche → Text
   „Kein Produkt gefunden“ (14, sub) mittig in der Karte.

## Daten – was pro Bon gespeichert wird
Heute: receipts(store_name, purchased_at date, total, line_count, saved_price_count, photo_paths, bytes, lines jsonb);
lines = [{raw, item, price, unit_price, quantity, saved}].
Neu (Migration 030_receipt_meta.sql, nur neue Spalten mit Standardwerten → Build 1/2 bleiben lauffähig):
- receipts.store_address text null – aus dem Bon: Zeile(n) direkt unter dem Laden mit Straße/Hausnummer bzw. PLZ.
- receipts.started_at timestamptz null – Einkaufsbeginn laut Liste (siehe unten).
- receipts.ended_at timestamptz null – Uhrzeit vom Bon (HH:MM neben/nahe dem Datum) kombiniert mit purchased_at;
  ohne Uhrzeit auf dem Bon: Zeitpunkt der Aufnahme.
- lines-JSON zusätzlich (optional, alte Einträge ohne diese Felder bleiben gültig): category (Name zum Zeitpunkt
  des Speicherns), units (Double, Inhalt je Stück), measure (Einheit wie im Artikel), item_id (falls zugeordnet).
  Nährwerte später als weiteres optionales Feld – jetzt nicht anlegen.
- Größenlimit der Check-Constraint für lines prüfen (bleibt bei 500 Zeilen ausreichend).
Einkaufsbeginn „laut Liste“: Beim ersten Abhaken in einer Liste, in der vorher nichts abgehakt war (bzw. nach dem
letzten „Einkauf erledigt“), lokal pro Liste merken (UserDefaults reicht, kein Sync nötig). Beim Speichern des Bons
in den Draft übernehmen und danach zurücksetzen. Plausibilität: Start nach Ende oder > 4 h vor Ende → verwerfen.
Dauer = ended_at − started_at in Minuten; nur anzeigen, wenn beides da ist.
Alte Bons: fehlende Kategorie/Einheit beim Anzeigen über den Artikelnamen aus Liste/Artikelstamm nachschlagen
(ReceiptItemMatcher/CategoryResolver), nicht zurückschreiben.

## Berechnungen (reine Funktionen → Unit-Tests)
- ReceiptInsights (neu, Features/Receipts/Services): Eingabe [ArchivedReceipt] + Monat + Kalender (de_DE,
  Europe/Berlin) → Summe, Anzahl, Ø, Δ % Vormonat, 6-Monats-Säulen + Schnitt, Kategorien (Top 6 + Sonstiges inkl.
  Differenz), Läden.
- ConsumptionStatistics (neu): gruppiert Zeilen nach Artikel-Schlüssel (PricePoint.key bzw. item_id), Menge =
  Σ quantity × units in measure; gemischte Einheiten eines Artikels → in Stück anzeigen; Mengen deutsch
  formatieren (QuantityFormat), „pro Woche“ = Monatsmenge / (Tage im Monat / 7). Nicht zugeordnete Zeilen zählen
  nicht zum Verbrauch.
- Ausstehende (lokal noch nicht hochgeladene) Bons zählen mit.
- Tests: Summe = Monatssumme trotz Rabatt/Pfand, Monatsgrenzen (letzter Tag 23:59, Zeitzone), Monate ohne Bons,
  Top-6-Regel, Mengenaddition l/ml/kg/g/Stück, Einkaufsbeginn-Logik, Parser für Uhrzeit und Adresse
  (ReceiptParserTests um Beispiel-Bons ergänzen: Edeka, Rewe, Lidl, dm).

## Umfang App
- ReceiptParser: detectTime, detectAddress; ParsedReceipt um time/address erweitern.
- ReceiptFlowViewModel → Draft/ArchivedReceipt/SupabaseReceiptsRepository um die neuen Felder erweitern
  (Spaltenliste ergänzen, Decoding tolerant für fehlende Spalten/Felder).
- ActiveListSheet: .receiptInsights(tab, month) mit baseSheet .receiptArchive(fromMenu:); Preisverlauf aus Detail
  und Verbrauch mit passendem baseSheet (Zurück landet wieder dort, wo man herkam).
- Neue Views: ReceiptInsightsCard, ReceiptMetaGrid, ReceiptLineRow, ReceiptInsightsSheet, SpendInsightsView,
  UsageInsightsView, MonthSwitcher, InsightBarChart, CategoryShareBar, UsageSparkline (Namen frei, eine Type je
  Datei). Diagramme als SwiftUI-Shapes (kein Swift Charts nötig; wenn doch, Aussehen exakt wie Board).
- UserLog (deutsch) in den ViewModels: „📊 Auswertung geöffnet (<Monat>)“, „📊 Monat gewechselt“.
- VoiceOver: Säulen und Kategorien als Liste mit Werten lesbar, Segment als Tabs, Monatsknöpfe mit Label.
- Offline: Auswertung rechnet nur mit lokal vorhandenen Bons, kein Netz nötig.
- #Preview Hell + Dunkel je Screen mit Beispieldaten (ArchivedReceipt.designSamples erweitern: Sept. 2026 mit
  den Werten aus den Boards – 412,37 €, 9 Einkäufe, Kategorien und Läden wie InsightSpend).
- Neue Dateien in project.pbxproj; UI-Test: Archiv → Karte → Auswertung → Verbrauch → Zeile → Preisverlauf → zurück.

## Vorgehen
Phase 0: Bestandsaufnahme + design-handoff/RECEIPT_INSIGHTS_PLAN.md (Datenmodell, Migration, Parser-Erweiterung,
Berechnungen, Sheet-Navigation, Risiken). Zeig mir den Plan und stell nur echte Blocker-Fragen.
Danach Phase für Phase (1 Daten + Parser, 2 Detail mit Metadaten, 3 Auswertung Ausgaben, 4 Verbrauch + Einstieg):
Build grün, Unit-Tests grün, Migration live getestet, Screens gegen die PNGs abgeglichen, eigener Commit je Phase,
kein Push ohne Okay. Build und Tests laut CLAUDE.md (Scheme Famlist, Ziele per id=).
Am Ende: SPEC.md §2/§3 und PLAN.md aktualisieren.
```
