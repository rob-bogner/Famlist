# Plan: Einkaufsdaten am Kassenzettel + Auswertung (Ausgaben, Verbrauch)

Stand 29.09.2026 · Auftrag: `RECEIPT_INSIGHTS_PROMPT.md` · Design freigegeben 28.09.2026
(ReceiptArchiveInsights, ReceiptDetailMeta, InsightSpend, InsightUsage, je Hell + Dunkel).

## 0. Bestandsaufnahme (geprüft am Code)

| Bereich | Heute | Folge für diesen Auftrag |
|---|---|---|
| `receipts` (Migr. 021, 029) | store_name, purchased_at (date), total, line_count, saved_price_count, photo_paths, bytes, lines jsonb | Neue Spalten nur mit Standardwert (Migration 030). |
| `ReceiptLine` | raw, item, price, unit_price, quantity, saved | Neue optionale Felder; alte JSON-Einträge bleiben gültig (synthetisches `Decodable` liest fehlende Optionale als nil). |
| `ArchivedReceipt` | Codable, liegt auch im lokalen Cache und in der Warteschlange | Neue Felder optional → alter Cache bleibt lesbar. |
| `ReceiptParser` | detectStore, detectDate, Positionen, Summe | detectTime, detectAddress neu. |
| `ReceiptFlowViewModel` | 329 Zeilen; kennt nur Namen, Preise und abgehakte Artikel der Liste | Wird aufgeteilt (Speichern in eigene Datei); bekommt Artikel der Liste, Artikelstamm und Kategorien. |
| `ItemModel.units` / `measure` | Menge **auf der Liste** (z. B. 2 l, 250 g, 10 Stück), kein „Inhalt je Stück“ | Regel für „Inhalt je Stück“ nötig → §2.3 und Frage F1. |
| `ReceiptDay` | Tag nach Ortszeit, Datum als 12 Uhr Ortszeit | Monatsgrenzen über Kalendertag, nicht über Uhrzeit. |
| Abhaken | Alle Wege (einzeln, Kategorie, „Alle abhaken“) rufen `noteCheckChange(wasComplete:)` | Dort den Einkaufsbeginn merken. |
| Sheets | `ActiveListSheet` mit `baseSheet`; `.priceHistory` liegt fest über „Artikel verwalten“ | Neuer Fall für Preisverlauf mit frei wählbarem Rückweg. |
| Watch | Kein Bezug zu Kassenzetteln (`grep` in FamlistWatch*: keine Treffer) | **Keine Änderung an der Watch.** |
| Bausteine | SheetSurface, SheetHeader, ListAccountTokens (segBg), Segment in SettingsSheet, GlassPillBackground, GlassCircleButton, FocusedSearchField, ListTheme.heroBg, CategoryIconCatalog, CategoryResolver | Wiederverwenden, nichts neu erfinden. |

## 1. Datenmodell und Migration 030

`migrations/030_receipt_meta.sql` (nur neue Spalten, Standard NULL → Build 1/2 schreiben und lesen weiter):

- `receipts.store_address text null`, Check: Länge ≤ 200.
- `receipts.started_at timestamptz null` – Einkaufsbeginn laut Liste.
- `receipts.ended_at timestamptz null` – Uhrzeit vom Bon, sonst Aufnahmezeit (Regel §2.2).
- Bewusst **keine** Check-Regel „started_at < ended_at“: Ein abgelehnter Insert bliebe in der Warteschlange
  hängen. Die App prüft die Plausibilität selbst.
- `lines` bekommt je Zeile optional `category`, `units`, `measure`, `item_id`. Größe: heute ca. 120 Byte je Zeile,
  neu ca. 230 Byte → 500 Zeilen ≈ 115 KB; die Grenze aus 029 (200 000 Byte) reicht. Wird im Prüfskript gemessen.
- Nährwerte: später als weiteres optionales Feld je Zeile (`nutrition`) bzw. eigene Tabelle je Artikel;
  **jetzt nichts anlegen**. Der Schlüssel `item_id` + Artikelname reicht, um sie später zuzuordnen.
- Prüfskript `migrations/tests/030_receipt_meta_check.sql` (in einer Transaktion, zurückgerollt): Spalten da,
  alte Zeile ohne neue Felder lesbar, zu lange Adresse abgelehnt, 500 Zeilen mit neuen Feldern erlaubt.
- Live anwenden wie bei 029 (Supabase MCP, einzeln), danach REST-Rundlauf mit Testkonto.

App-Seite:
- `ArchivedReceipt`: `storeAddress`, `startedAt`, `endedAt` (optional).
- `ReceiptLine`: `category`, `units`, `measure`, `itemId` (optional, JSON-Schlüssel `category`, `units`,
  `measure`, `item_id`).
- `ReceiptArchiveDraft`: dieselben drei Metadaten.
- `SupabaseReceiptsRepository`: Spaltenliste und `Row` ergänzen (neue Felder optional → tolerant).

## 2. Erfassen beim Speichern

### 2.1 Parser
- `detectTime`: 1. Uhrzeit `HH:MM(:SS)` in der Datumszeile; 2. sonst in den zwei Zeilen danach bzw. davor;
  3. sonst TSE-Zeitstempel (`2026-09-24T17:42:10`, „TSE-Stop“ bevorzugt). Preise haben Komma, Uhrzeiten
  Doppelpunkt → keine Verwechslung.
- `detectAddress`: in den ersten 8 Zeilen nach dem Laden die erste Zeile mit Straßenmuster
  (…str., …straße, …weg, …platz, …allee, …gasse, …ring, …damm + Hausnummer); sonst eine Zeile „PLZ Ort“.
- `ParsedReceipt` um `time` (Stunde/Minute) und `address` erweitern.
- Tests: synthetische Beispiel-Bons im Format von Edeka, Rewe, Lidl, dm (Aufbau nach öffentlichen Beispielen
  nachgebaut, keine echten Scans).

### 2.2 Uhrzeit, Beginn, Dauer
- `ended_at` = Bon-Datum + Bon-Uhrzeit (Kalender Europe/Berlin). Ohne Uhrzeit auf dem Bon: Zeitpunkt der
  ersten Aufnahme, **aber nur**, wenn deren Tag dem Bon-Datum entspricht (sonst nil – ein alter Bon, der
  heute fotografiert wird, bekäme sonst eine falsche Uhrzeit).
- Einkaufsbeginn (`ShoppingStartTracker`, UserDefaults je Liste, kein Sync): In `noteCheckChange` wird der
  Zeitpunkt gemerkt, wenn vorher nichts abgehakt war **oder** der gemerkte Zeitpunkt älter als 4 h ist.
  Zurückgesetzt wird er nach „Preise speichern“ (nach Übernahme in den Draft) und nach „Einkauf erledigt“.
- Plausibilität: Start nach Ende oder mehr als 4 h vor Ende → Start verwerfen.
- Dauer = ended_at − started_at in Minuten; nur anzeigen, wenn beides da ist.

### 2.3 Kategorie, Einheit, Inhalt je Zeile
Beim Speichern schlägt `ReceiptLineEnricher` jede zugeordnete Zeile nach: erst Artikel der Liste (alle, nicht nur
abgehakte), dann Artikelstamm. Gespeichert werden der Kategorie-Name (über `CategoryResolver` mit den
Kategorien des Nutzers), `measure`, `item_id` und `units` als **Inhalt je Stück**.

Weil `ItemModel.units` die Menge auf der Liste ist, gilt (Entscheidung Robert 29.09.2026, Frage F1):
**Die Listenmenge ist die Gesamtmenge der Bon-Zeile.** Gespeichert wird `units` = Listenmenge ÷ Bon-Stückzahl,
damit Stückzahl × units wieder genau die Listenmenge ergibt.
- „Schokolade 200 g“, Bon 2 × → units 100 g → „2 × 100 g“ (wie im Board), Verbrauch 200 g.
- „Milch 2 l“, Bon 2 × → „2 × 1 l“, Verbrauch 2 l. „Butter 250 g“, Bon 1 × → „1 × 250 g“.
- Bekannte Schwäche: Wird mehr gekauft als auf der Liste steht („Milch 1 l“, Bon 2 ×), zählt nur 1 l.

Alte Bons ohne diese Felder: beim Anzeigen über den Artikelnamen in der geöffneten Liste nachschlagen, nicht
zurückschreiben. Umgesetzt ohne Artikelstamm (Phase 2): Der liegt hinter einem asynchronen Repository, und Bon-Zeilen
ohne Kategorie gibt es nur vom 28.09.2026 (zwischen Migration 029 und 030).

## 3. Berechnungen (reine Funktionen, Unit-Tests)

- `ReceiptInsights.make(receipts:month:calendar:categoryOf:)` → Summe, Anzahl, Ø, Δ % zum Vormonat (ohne Bons im
  Vormonat: nil), 6 Monatssäulen + Schnitt (nur Monate mit Bons), Kategorien, Läden.
- Kategorien: Beträge je Kategorie aus den Zeilen; höchstens 6 nach Betrag; Rest, nicht zugeordnete Zeilen und
  die Differenz „Summe laut Bon − Σ Zeilen“ (Pfand, Rabatte; auch negativ) → „Sonstiges“. Damit ist Σ genau die
  Monatssumme. Bons ohne Zeilen (alte App-Version) gehen ganz in „Sonstiges“.
- Farben (`InsightPalette`, Hell/Dunkel wie im Auftrag): Rang je Kategorie über **alle** Bons des Archivs nach
  Betrag; Farbe = Palette[Rang mod 6]; „Sonstiges“ grau. Dieselbe Zuordnung in Detail und Verbrauch.
- `ConsumptionStatistics`: Gruppierung nach `PricePoint.key(Artikelname)`; Menge = Σ quantity × units in der
  Einheit; g↔kg, ml↔l umrechnen (wie `QuantityMerge`); unterschiedliche Einheitsarten → Stück; Anzeige über
  `QuantityFormat`; „pro Woche“ = Monatsmenge ÷ (Tage im Monat ÷ 7); Sortierung nach Anzahl Käufe, dann Kosten;
  nicht zugeordnete Zeilen zählen nicht. Hero = Produkt mit der größten Menge (Stückzahl) im Monat.
- Ausstehende Bons zählen mit; alles rechnet nur mit lokal vorhandenen Bons (offline).
- Kalender: gregorianisch, Europe/Berlin, de_DE; Monat eines Bons = Kalendertag von purchased_at.
- Tests: Rabatt/Pfand, Monatsgrenzen (31.08. 23:59 / 01.09. 00:00, Zeitzone), Monate ohne Bons, Top-6-Regel,
  Mengen l/ml/kg/g/Stück, Einkaufsbeginn, Parser Uhrzeit/Adresse.

## 4. Screens und Navigation

| Sheet | Neu/geändert | Zurück bzw. ✕ |
|---|---|---|
| Archiv | Karte `ReceiptInsightsCard` unter der Unterzeile (nur wenn Bons existieren) | wie heute |
| Detail | `ReceiptDetailSheet` wird zu ReceiptDetailMeta: `ReceiptMetaGrid`, Segment Artikel/Bon-Foto, `ReceiptLineRow` | Zurück → Archiv |
| Auswertung | `.receiptInsights(tab, month, fromMenu)`, baseSheet = Archiv; `ReceiptInsightsSheet` mit `SpendInsightsView` / `UsageInsightsView`, `MonthSwitcher` | ✕ → Archiv |
| Preisverlauf | `indirect case receiptPriceHistory(ItemCatalogEntry, back: ActiveListSheet)`; baseSheet = back | Zurück → Detail bzw. Auswertung (gleicher Reiter und Monat) |

- Weitere Views (eine Type je Datei): `InsightBarChart`, `CategoryShareBar`, `UsageSparkline`, `InsightChip`,
  `InsightHeroCard`. Diagramme als SwiftUI-Shapes, Maße aus den `.dc.html`-Boards.
- `ReceiptInsightsViewModel` (@MainActor): Monat, Reiter, Suche, Berechnung; UserLog „📊 Auswertung geöffnet
  (<Monat>)“, „📊 Monat gewechselt“.
- Zeilen ohne zugeordneten Artikel sind nicht tippbar.
- VoiceOver: Säulen und Kategorien als Liste mit Werten, Segment als Tabs, Monatsknöpfe mit Label.
- Leere Zustände wie im Auftrag §6.
- Design-Modus/Screenshot-Tour: neue Namen `receiptInsights`, `receiptInsightsUsage`, `receiptDetail` (Meta).
- Beispieldaten: `ArchivedReceipt.insightSamples` (Apr–Sep 2026: 356, 389, 372, 401, 382, 412,37 €; September mit
  9 Bons, Kategorien und Läden wie InsightSpend, Artikel wie InsightUsage); `designSamples[0]` bekommt die
  Zeilen und Metadaten aus ReceiptDetailMeta.

## 5. Abweichungen der Boards untereinander (keine Blocker, so umgesetzt)

1. ReceiptArchiveInsights zeigt „412,37 € · 9 Einkäufe“, darunter aber nur 3 September-Bons und „12 Bons“.
   Beides zugleich ist mit echten Daten nicht möglich. Die Karte rechnet immer aus den gezeigten Bons; im
   Design-Modus des Archivs steht deshalb „117,58 € · 3 Einkäufe“.
2. InsightUsage zeigt „Butter 5 × 250 g“, der Auftrag verlangt Σ Menge in der Einheit → „1,25 kg“. Umgesetzt
   wird die Regel aus dem Auftrag.
3. Ort-Kachel: Board „Edeka Center“, die App kennt nur den Kettennamen („EDEKA“). Angezeigt wird der
   erkannte Laden, darunter die Adresse.
4. ReceiptDetailMeta färbt „Konserven“ mit einem eigenen Ton (#D07A4A), den der Auftrag nicht vorsieht.
   Umgesetzt: Palette nach Rang (im Design-Modus wie Backwaren, orange).
5. Der weiche Auslauf (70 pt) liegt laut HTML über „Teilen“/„Löschen“; im PNG wirken die Knöpfe klarer.
   Umgesetzt wie im HTML; beim Scrollen kommen die Knöpfe heraus.
6. Bons ohne gespeicherte Zeilen (vor Migration 029) zeigen kein Segment, sondern direkt die Fotos.
7. InsightSpend zeigt „Rewe 2 × · Ø 65,72 €“; 131,45 € ÷ 2 = 65,725 € rundet kaufmännisch auf 65,73 €
   (das Board rundet vermutlich mit Gleitkomma). Die App rechnet mit Decimal → „65,73 €“.
8. Unter der Auswertung liegt im Board die Einkaufsliste, nicht das Archiv. Deshalb kein Sheet darunter;
   ✕ führt trotzdem ins Archiv (Auftrag).
9. Monatswechsel: gesperrte Knöpfe sind nicht gestaltet → 40 % Deckkraft.
10. InsightUsage zeigt „3,5 l pro Woche“ (14 l ÷ 4). Der Auftrag rechnet Monatsmenge ÷ (Tage ÷ 7):
    14 l ÷ (30 ÷ 7) = 3,27 → „3,3 l pro Woche“ (eine Nachkommastelle). Umgesetzt nach Auftrag.
11. „6 Laibe“: Die App kennt keine Einheit „Laib“ (Measure); Brot erscheint als „6 Stück“.
12. „Hackfleisch 2,0 kg“ / „Kaffee 2 kg“ sind im Board uneinheitlich; die App schreibt immer „2 kg“ (QuantityFormat).
13. Die Suche filtert nur die Liste; der Hero bleibt beim meistgekauften Produkt des Monats.
14. Verbrauch ohne Käufe im Monat (nicht gestaltet): Hero „Verbrauch im <Monat> · 0,00 €“, Chip „Keine Einkäufe“.
15. Board-Icons der Kategorien (eigene Glyphen) → Icons der Kategorien des Nutzers (CategoryIconCatalog), wie im Auftrag.

## 6. Phasen (je Phase: Build grün, Unit-Tests grün, eigener Commit, kein Push) – alle erledigt 29.09.2026

1. **Daten + Parser:** Migration 030 (live + Prüfskript + REST-Rundlauf), Modelle, Repository, Parser,
   ShoppingStartTracker, ReceiptLineEnricher, Flow-ViewModel aufteilen + erweitern, Tests.
2. **Detail mit Metadaten:** ReceiptDetailMeta, Preisverlauf aus dem Detail, Abgleich mit PNG Hell/Dunkel.
3. **Auswertung Ausgaben:** ReceiptInsights, InsightPalette, Sheet + Monatswechsel + Diagramme, Tests, Abgleich.
4. **Verbrauch + Einstieg:** ConsumptionStatistics, UsageInsightsView, Karte im Archiv, UI-Test
   (Archiv → Karte → Auswertung → Verbrauch → Zeile → Preisverlauf → zurück), SPEC.md §2/§3, PLAN.md.

## 7. Risiken

- Bon-Formate sind nur an nachgebauten Beispielen getestet; echte Bons können Uhrzeit/Adresse anders drucken
  → dann bleibt das Feld leer („–“), nichts Falsches.
- „Inhalt je Stück“ ist eine Ableitung aus der Listenmenge (§2.3); wird mehr oder weniger gekauft als auf der
  Liste steht, weicht der Verbrauch ab.
- Gewichtsartikel (Bananen 0,512 kg): Der Parser verwirft heute das Gewicht der Waagezeile. Verbrauch in kg
  stimmt nur, wenn die Listenmenge das Gewicht trifft. Waagegewicht übernehmen wäre eine Parser-Erweiterung
  (nicht im Auftrag; als Folgeschritt vorgeschlagen).
- Im Arbeitsbaum liegen fremde, ungetestete Änderungen (ProductDetail*, HybridSheetLayer, SheetQuantityStepper)
  und der Canvas-Abgleich; sie werden in keinen Phasen-Commit übernommen.
