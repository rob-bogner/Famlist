# PLAN – Redesign „Hybrid“ (vollständig)

Stand: 24.09.2026 · Branch `redesign-hybrid` (abgezweigt von `main` 20ea307)

## Fortschritt

- [x] Phase 0 – Bestandsaufnahme (dieses Dokument)
- [x] Phase 1 – Fundament
- [x] Phase 2 – Liste und Dock
- [x] Phase 3 – Artikel
- [x] Phase 4 – Listen, Teilen, Konto
- [x] Phase 5 – Einstieg
- [x] Phase 6 – Kategorien
- [ ] Phase 7 – Kassenzettel und Preise (**in Arbeit**, Stand 24.09.2026 21:00)
  - Fertig, aber noch NICHT im Xcode-Projekt eingetragen und nicht gebaut: `Famlist/Features/Receipts/**`
    (ReceiptParser, ReceiptItemMatcher, PriceStatistics, ReceiptTextRecognizer, ReceiptCamera, PriceBook,
    ReceiptFlowViewModel, PriceHistoryViewModel, ReceiptCaptureView, ReceiptReviewSheet, ShoppingDoneView,
    PriceHistorySheet, CameraPreviewView, ViewfinderCorner), `Repositories/*PricePoints*`,
    Tests `ReceiptParserTests.swift`, `ReceiptFlowTests.swift`. Migration 012 ist angewandt und geprüft.
  - Offen: 1) `PriceHistoryChart` um Parameter `values: [Double?]` und `average: Double?` erweitern
    (y = 114,4 − (v − min)/(max − min) · 75, x = i · 53; Durchschnittslinie auf avg);
    2) PriceBook in FamlistApp erzeugen (SupabasePricePointsRepository) und bereitstellen;
    3) ActiveListSheet: .receiptCapture (Vollbild), .receiptReview, .shoppingDone, .priceHistory(ItemCatalogEntry)
       (Basis .manageItems); ☰ „Kassenzettel scannen“ öffnet .receiptCapture; ManageItemsSheet `onPriceHistory` setzen;
       „Abgehakte löschen & fertig“ → listViewModel.deleteCheckedItems();
    4) Dateien eintragen (xadd), bauen, Tests laufen lassen, Screenshots gegen ReceiptCapture/ReceiptReview/
       ShoppingDone/PriceHistory, PLAN §8a/§9 ergänzen, committen.

---

## 1. Ausgangslage (geprüft, nicht angenommen)

### 1.1 Das Fundament ist schon da

Ein früherer Stand desselben Design-Pakets ist bereits in der App. Er wurde am 24.09.2026 aus `~/Downloads/MyListUI` und `~/Downloads/MyListUI 2` übernommen und nach der Projektregel „ein Typ pro Datei“ aufgeteilt.

Ich habe das neue Paket per `diff` mit `MyListUI 2` verglichen:

| Datei im Paket | Unterschied zu `MyListUI 2` |
|---|---|
| Support/AppFont.swift, CSSRendering.swift, Theme/Theme.swift, ProductImageScreen.swift | identisch |
| Support/SVGIcons.swift | 1 Leerzeichen (kein inhaltlicher Unterschied) |
| Components/SheetComponents.swift | nur die Reihenfolge der Argumente eines Preview-Aufrufs |
| SearchScreen, ItemFormScreens, MyListsScreen | nur explizite Initializer (Compiler-Korrekturen) und ein neuer Hintergrund-Wrapper |
| Screens/ListScreen.swift | **echte Änderung**, 244 Zeilen: Label „Aktuelle Liste“, Knopf „Ansicht wechseln“ und die Chips „offen/erledigt“ sind weg; neuer Zustand `.empty`; neues Dock `DockView` |
| Components/Dock.swift, OverlayComponents.swift und 8 Screen-Dateien | **neu** |

Folge für Phase 1: Die Dateien aus `Support/` und `Theme/` werden nicht noch einmal kopiert. Sonst gäbe es doppelte Typen, denn `AppFont`, `SVGIcon`, `AccentScale`, `CSSBox`, `CSSLinearGradient`, `CSSRadialGradient`, `BoxShadow`, `RGB`, `Paint`, `Appearance`, `Icon`, `TopBorderHairline` und die globalen `Pill`, `RR()`, `stop()` existieren schon unter `Famlist/Core/DesignSystem/Hybrid/`. Neu übernommen werden nur die fehlenden Typen, und zwar mit unverändertem Inhalt, aufgeteilt auf eigene Dateien.

### 1.2 Architektur und Navigation

- **Einstieg:** `FamlistApp` → `RootView`. Die Sitzung wird wiederhergestellt; mit Anmeldung erscheint `ShoppingListView`, ohne Anmeldung `AuthView`. Es gibt keinen `NavigationStack` und keine `TabView`.
- **Sheets:** eigene Hybrid-Ebenen über `enum ActiveListSheet` (`search`, `newItem`, `edit`, `productImage`, `lists`, `listName`). Dazu kommen alte System-Sheets für Teilen, Mitglieder, Import und Profil sowie `confirmationDialog`s für Löschen und Duplizieren.
- **Mehr-Menü ☰:** ein System-`Menu` mit 9 Einträgen (Import, Alle abhaken, Löschen…, Mitglieder, Liste teilen, Profil, Abmelden).
- **Dock:** `ListDock` mit Pille „Liste“, Sortier-Menü, Duplizieren, „Erledigte löschen“ und einem FAB, der die **Suche** öffnet.

### 1.3 Datenmodell, Persistenz, Sync

- **SwiftData:** `ItemEntity`, `ListEntity`, `SyncOperation`. Es gibt keinen `VersionedSchema`; Änderungen laufen bisher als leichte automatische Migration über Standardwerte.
- **Artikel** laufen offline-first über die `SyncEngine`: lokal speichern → Warteschlange → Supabase. Konflikte löst Last-Writer-Wins nach HLC. **Ein Tombstone (gelöschter Artikel) gewinnt immer.**
- **Die Artikel-ID ist deterministisch** und wird aus `listId:name` berechnet.
- **Listen** gehen direkt an Supabase, ohne SyncEngine. Eine Liste anzulegen scheitert offline.
- **Backend:** Supabase-Projekt „Famllist“ (`mbfztpbwfktiduemqqfe`), live geprüft am 24.09.2026. Tabellen: `lists`, `items`, `list_members`, `profiles`, `categories` (0 Zeilen, in der App nicht verdrahtet), `item_catalog` (persönlicher Artikelstamm, 110 Zeilen), `global_product_catalog` (Open-Food-Facts-Auszug DACH, **227.121 Zeilen, Primärschlüssel = EAN**).
- `items.position` (int) gibt es in der Datenbank schon, in der App aber nicht.
- Es gibt keine Storage-Buckets und keine eigenen RPCs. Die beiden Edge Functions (`publish-to-room`, `make-server-515802c7`) verwendet die App nicht.

### 1.4 Auth, Teilen, Konto

- **Anmeldung:** E-Mail per Magic Link und E-Mail mit Passwort. Supabase kennt nur den Provider `email`. Sign in with Apple fehlt, anonyme Anmeldung auch.
- **Profil:** Es wird nach dem ersten Login automatisch angelegt, mit zufälliger 8-stelliger `public_id`. Der Benutzername wird in `ProfileView` **nicht gespeichert** (dort steht nur ein TODO).
- **Einladung:** `famlist://invite?listId=…&inviterPublicId=…&listTitle=…`. Der Link wird auch vor dem Login gemerkt; beim Annehmen trägt sich der Nutzer selbst in `list_members` ein. Universal Links gibt es nicht, und es gibt keine `.entitlements`-Datei.
- **Fehlt ganz:** Konto löschen, Liste verlassen, Einstellungen, Erscheinungsbild-Wahl, Benachrichtigungen, Barcode-Scanner, Preisverlauf, Kassenzettel, Kopieren in die Zwischenablage, Löschen mit Rückgängig.

### 1.5 Build und Tests

- **Deployment Target:** App iOS 17.0 (erfüllt die Mindestversion). `FamlistTests` iOS 26.2. `SWIFT_VERSION = 5.0`.
- **Schriften:** Outfit und DM Sans sind als Variable Fonts eingebunden und in `UIAppFonts` eingetragen. `AppFont.Family` nutzt „Outfit“ und „DM Sans“.
- **pbxproj:** klassische Dateireferenzen. Jede neue Datei muss in der pbxproj eingetragen werden.
- **String Catalog:** `Famlist/Shared/Resources/Localizable.xcstrings` (Quellsprache en, 177 Keys).
- **Tests:** 31 Unit-Testdateien, 23 UI-Tests. Letzter Voll-Lauf: 335 Unit-Tests grün. Zwei Tests scheitern gelegentlich (`DeleteListTests…rollsBackList`, `SwipeUITests.test_C_left_fromThumbnail`).
- **Simulator:** iPhone 17 Pro, iOS 26.5, id `F1ECDBCC-15DC-4E12-8B57-9A6D5073B1AF`.

---

## 2. Mapping: bestehender Code → neuer Screen

| Neuer Screen (SPEC §2) | Bestehender Code | Aktion |
|---|---|---|
| `ListScreen` (.normal/.checked/.swipe/.empty) | `ShoppingListView`, `ShoppingListContent`, `ListTopBar`, `ProgressHero`, `ListFilterTabs`, `ListSectionHeader`, `ItemCard`, `SwipeableItemRow` | anpassen: Label, 2. Kreis und Chips entfernen; Leer-Zustand neu. Die auf dem Gerät eingestellte Wischgeste bleibt. |
| `DockView` (7 Zustände) | `ListDock` | ersetzen |
| `MenuOverlayScreen` ☰ | System-`Menu` in `ShoppingListView` | ersetzen, 6 Einträge (Entscheidung F1/F4) |
| `SortMenuScreen` | Sortier-`Menu` in `ListDock`, `SortOrder` (global, nicht gespeichert) | neu; Modus „Manuell“ und Speichern pro Liste neu |
| `CopyChoiceScreen` / `CopyDoneScreen` | – | neu |
| `DeleteChoiceScreen` / `UndoToastScreen` | `confirmationDialog` + `deleteCheckedItems`/`deleteAllItems` | ersetzen; Rückgängig neu |
| `SearchEmptyScreen` / `SearchResultsScreen` | `ItemSearchSheet` (2 Abschnitte „Deine Artikel“/„OpenFood“) | angleichen: eine Trefferliste „n Treffer“; Scan-Knopf neu |
| `NewItemScreen` | `NewItemSheet` | angleichen; FAB öffnet es direkt |
| `EditItemScreen` | `EditItemSheet` | angleichen (ohne Preisverlauf-Link, SPEC §5) |
| `ProductImageScreen` | `ProductImageSheet` | angleichen |
| `ManageItemsScreen` | – (nur Suche in `item_catalog`) | neu |
| `BarcodeScanScreen` | – | neu (VisionKit) |
| `PriceHistoryScreen` | – | neu |
| `MyListsScreen` | `MyListsSheet`, `ListSummaryCard`, `SwipeableListCard` | angleichen: Wischaktionen und Kontextmenü entfernen, langer Druck öffnet Listen-Optionen (SPEC §3.6) |
| `CreateListScreen` | `ListNameSheet` (Modus neu) | angleichen: Favorit-Schalter |
| `ListOptionsScreen` | Wisch-/Kontextaktionen, `duplicateActiveList` | neu, bündelt alle Listen-Aktionen |
| `ShareMembersScreen` | `ShareListView` + `MembersView` (System-Sheets) | ersetzen, beide zusammen |
| `SettingsScreen` | – (Abmelden im Mehr-Menü) | neu |
| `EditProfileScreen` | `ProfileView` (speichert nicht) | ersetzen, Speichern echt bauen |
| `DeleteAccountScreen` | – | neu |
| `SignInScreen` | `AuthView` | ersetzen |
| `ProfileSetupScreen` | – (Profil wird still angelegt) | neu |
| `AcceptInviteScreen` | `InviteAcceptView` (System-Sheet) | ersetzen |
| `ManageCategoriesScreen` / `EditCategoryScreen` | `ItemCategory` (festes Enum, 8 Werte) | neu, Kategorien werden benutzerdefiniert |
| `ReceiptCaptureScreen` / `ReceiptReviewScreen` / `ShoppingDoneScreen` | – | neu |

**Wegfallende Funktionen** (weil sie im Design nicht mehr vorkommen): Knopf „Ansicht wechseln“, Wischaktionen auf Listenkarten, „Liste duplizieren“ im Dock (wandert in die Listen-Optionen), Modus-Picker Magic Link/Passwort in `AuthView` (Entscheidung F2).

---

## 3. Fehlende Funktionen: Datenmodell und Backend

Alle Supabase-Änderungen kommen als nummerierte Datei nach `migrations/` (ab `008_…`) und werden per `apply_migration` angewandt. SwiftData-Felder bekommen Standardwerte, damit die leichte Migration greift und bestehende Nutzerdaten erhalten bleiben.

| Funktion | Lokal (SwiftData) | Supabase |
|---|---|---|
| Manuelle Reihenfolge | **geändert in Phase 2:** geordnete Artikel-IDs pro Liste in UserDefaults (`ManualOrderStore`), nicht synchronisiert | – (`items.position` bleibt ungenutzt) |
| Sortierung pro Liste | `ListSortSettings` pro `listId` in UserDefaults (nur auf diesem Gerät) | – |
| Favorit = öffnet beim Start | – | **neu** `profiles.favorite_list_id uuid`. Grund: `lists.is_default` gehört zur Liste und damit allen Mitgliedern; ein Mitglied darf es per RLS nicht ändern. `is_default` bleibt als Rückfall für Altdaten. |
| Liste verlassen | – | **neu** Policy `lm_self_delete` (`profile_id = auth.uid()`) |
| Konto löschen | lokalen Store leeren | **neu** RPC `delete_my_account()` (SECURITY DEFINER): löscht eigene Listen samt Artikeln, Mitgliedschaften, Katalog, Kategorien, Preispunkte, Profil und `auth.users`-Zeile |
| Benutzername | – | `profiles.username` existiert (unique, ≥ 3 Zeichen); Live-Prüfung per `select … where username = …` |
| Profilfoto | – | Storage-Bucket `avatars` **existierte bereits (privat, leer)** und bleibt privat: lesen dürfen angemeldete Nutzer (signierte Links), schreiben nur im eigenen Ordner; `profiles.avatar_url` speichert den Pfad |
| Benachrichtigungs-Schalter | – | **neu** `profiles.notify_shared_lists bool`, `profiles.notify_invites bool` (siehe Risiko R5) |
| Kategorien mit Ladenweg | neu `CategoryEntity` als Cache | `categories` erweitern: `position int`, `icon text`, `updated_at`. Beim ersten Start werden die 8 bisherigen Kategorien pro Nutzer angelegt. „Sonstiges“ ist geschützt. |
| Barcode | – | `global_product_catalog.code` (vorhanden); **neu** `item_catalog.barcode text` für eigene Artikel |
| Preispunkte | neu `PricePointEntity` + Upload-Warteschlange | **neu** `stores(id, profile_id, name)` und `price_points(id, profile_id, catalog_item_id → item_catalog, store_id, purchased_at date, price numeric, created_at)`. Preispunkte werden nur angelegt, nie geändert; darum gibt es keine Konflikte. |

---

## 4. Entscheidungen (ohne Rückfrage getroffen)

1. **Ein Typ pro Datei.** Die Referenz-Views werden inhaltlich 1:1 übernommen, aber nach der Projektregel auf Dateien aufgeteilt, wie beim ersten Paket. Beispieldaten und leere Callbacks werden durch ViewModel-Daten und Aktionen ersetzt.
2. **Dock-Maße aus `Dock.swift`.** Die README nennt „Pille 68, FAB 68, Abstand 12“. `Dock.swift`, `Dock.dc.html` und `DockStates.png` zeigen dagegen Leiste 276 × 64, Pille 54, FAB 64, Abstand 10. Die README ist veraltet; es gelten die Werte aus dem HTML.
3. **Hintergrund der Sheets.** Wo der Referenzcode als Hintergrund einen `ListScreen` mit Beispieldaten einbettet (`ListAccountBackdrop`, `SheetScreen`), zeigt die App die echte Liste über die vorhandene `HybridSheetLayer` (Weichzeichner 3, `opaque: false`).
4. **Barcode-Namen** kommen aus der eigenen Tabelle `global_product_catalog` (227.121 EANs). Open Food Facts wird nicht live abgefragt. Das spart eine Netzabhängigkeit und Datenschutzfragen. Kein Treffer → „Neuer Artikel“ mit leerem Namen.
5. **Löschen mit Rückgängig** wird verzögert ausgeführt: Die Artikel verschwinden sofort aus der Anzeige; der Tombstone wird erst nach Ablauf der 5 s (oder wenn die App in den Hintergrund geht) geschrieben. Grund: Ein Tombstone gewinnt im Konfliktlöser immer, und die Artikel-ID ist deterministisch. Ein „Wiederherstellen“ nach dem Löschen würde deshalb vom Sync überschrieben.
6. **Kopier-Textformat:** erste Zeile Listenname, dann je Artikel `• Name · Menge Einheit`. Ist die Menge 1 und die Einheit leer, entfällt der Teil nach `·` (Beispiel in `CopyChoiceScreen` prüfe ich in Phase 2 gegen das HTML).
7. **Sortierung pro Liste nur lokal**, nicht synchronisiert. Die SPEC sagt „pro Liste gespeichert“, nicht „für alle Mitglieder“.
8. **Dynamic Type bleibt aus**, wie im Referenzcode (README „Grenzen“ Punkt 6). Der Prompt verlangt, dass Dynamic Type das Layout nicht bricht; mit festen Größen ist das erfüllt. VoiceOver-Labels übernehme ich aus den `aria-label`s, Tap-Flächen mindestens 44 pt.
9. **Strings:** deutsche Texte als Keys im vorhandenen `Localizable.xcstrings`. Englische Übersetzungen werden nicht neu gepflegt.
10. **Artikelstamm** = `item_catalog`. Bearbeiten und Löschen dort gehen wie bisher direkt an Supabase (kein Offline-Betrieb). Siehe Risiko R3.
11. **Preisverlauf** ist erreichbar über das System-Kontextmenü (langer Druck) in „Artikel verwalten“, Eintrag „Preisverlauf“ (SPEC §5).
12. **Einbindung der Referenz-Screens:** Jeder Screen legt sich im Referenzcode eine Beispiel-Liste als Hintergrund unter (`ListAccountBackdrop`, `EKKSheetStage`, `OverlayStage`, `SheetScreen`). In der App setzt der Host den Umgebungswert `hybridHosted = true`; dann zeichnen diese Bausteine nur ihren Inhalt, und Weichzeichner + Abdunkelung kommen vom Host über der echten Liste. Die Vorschauen nutzen `DesignListScreen` (die statische Referenz-Liste) als Hintergrund. Sheet-Höhen werden über `hybridSheetMaxHeight` auf Bildschirmhöhe − 54 begrenzt.
13. **Profilfoto** wird auf 512 px verkleinert und als JPEG in den Bucket `avatars` geladen.

---

## 5. Blocker-Fragen – beantwortet von Robert am 24.09.2026

| Frage | Antwort | Folge |
|---|---|---|
| F1 – Einstieg Kassenzettel (im Design nicht vorhanden) | Eintrag im ☰-Menü | neuer Eintrag „Kassenzettel scannen“, Icon `camera`, gleicher Zeilenstil wie die anderen Einträge |
| F2 – E-Mail-Anmeldung (Screen ohne Passwortfeld) | Magic Link und „Mit Apple anmelden“ | Passwort-Anmeldung und Registrierung per Passwort entfallen in der UI. Nach „Weiter mit E-Mail“ erscheint ein Toast „Wir haben dir einen Link geschickt“. Rückkehr über `famlist://login-callback` (vorhanden). Die Simulator-Testkonten bleiben nur in DEBUG. |
| F3 – Universal Links | Keine Domain, Deep Link reicht | Einladungen bleiben `famlist://invite?…`; keine Associated Domains |
| F4 – Import aus der Zwischenablage | Als eigener Eintrag im ☰-Menü behalten | Eintrag „Aus Zwischenablage importieren“, Icon wie „Kopieren“ im Dock. `ClipboardImportView` wird auf eine Hybrid-Sheet-Ebene umgestellt, im Stil der anderen Sheets. |

**Das ☰-Menü hat damit 6 statt 4 Einträge:** Mitglieder & Teilen, Artikel verwalten, Kategorien verwalten, Kassenzettel scannen, Aus Zwischenablage importieren, Einstellungen. Die zwei zusätzlichen Einträge sind eine bewusste Abweichung von SPEC §3.5 (siehe Abschnitt 9). Das Popover wird dadurch um 2 Zeilen höher.

## 6. Voraussetzungen, die nur Robert erledigen kann

- **Sign in with Apple (Phase 5):** Capability im Apple-Developer-Konto für `com.roxo.famlist`, dazu Provider „Apple“ im Supabase-Dashboard (Services ID, Key). Ohne das lässt sich der Knopf bauen, aber nicht testen.
- **Kamera-Test (Phase 3 und 7):** VisionKit `DataScannerViewController` läuft nicht im Simulator; Scanner und Bon-Aufnahme lassen sich nur auf dem iPhone prüfen.

## 7. Risiken

- **R1 – Umfang:** 33 Screens, 8 neue Funktionen, 5 Migrationen. Pro Phase eine eigene Session hält die Qualität hoch (Tipp aus `START_HIER.md`).
- **R2 – Kategorien sind benutzerdefiniert, Artikel speichern den Kategorienamen als Text.** Umbenennen oder Löschen einer Kategorie muss die Artikel des Nutzers mit ändern (über die SyncEngine). In geteilten Listen sieht jedes Mitglied die Reihenfolge seiner eigenen Kategorien; unbekannte Namen landen unter „Sonstiges“.
- **R3 – Offline:** Listen, Artikelstamm und Kategorien laufen nicht über die SyncEngine. Das verletzt die Offline-First-Regel aus CLAUDE.md schon heute. Ich baue es im gleichen Muster wie bisher und löse es nicht in diesem Redesign.
- **R4 – `delete_my_account()` löscht `auth.users`.** Das ist endgültig. Die Funktion bekommt einen eigenen Test gegen ein Testkonto.
- **R5 – Benachrichtigungen:** Es gibt keinen Push-Versand (kein APNs-Schlüssel, kein Server-Code). Die Schalter speichern nur die Einstellung und fragen die Berechtigung an. Das Senden ist nicht Teil dieses Plans.
- **R6 – Zwei Tests scheitern gelegentlich** (siehe 1.5). Ein roter Voll-Lauf ist nicht automatisch ein neuer Fehler.
- **R7 – Wischgeste:** Die Werte der Artikel-Wischgeste sind auf dem Gerät eingestellt und durch 14 UI-Tests abgesichert. Ich übernehme nur Optik aus `SwipeActions`, nicht die Gestenlogik des Referenzcodes.

---

## 8. Phasen (Reihenfolge wie im Prompt)

Jede Phase endet mit: Build grün, Tests grün (außer R6), Previews Light/Dark 390 × 844, Screenshot-Abgleich im Simulator gegen `Design/png`, Commit, Haken oben.

1. **Fundament:** fehlende Typen aus `Components/` (Dock, OverlayComponents, SheetComponents-Rest) übernehmen; Icons aus `SVGIcons.swift` ergänzen, die in `Icon.swift` fehlen; Schriftnamen per `UIFont.familyNames` prüfen.
2. **Liste und Dock:** `ListScreen`-Änderungen, `DockView` mit `matchedGeometryEffect`, Sortieren (inkl. Manuell + `position`), Kopieren, Löschen + Rückgängig, ☰-Overlay mit 4 Einträgen, FAB → Neuer Artikel. Unit-Tests: Sortierung, Kopier-Text, Löschen/Rückgängig.
3. **Artikel:** Suche, Neuer Artikel, Bearbeiten, Produktbild, Artikel verwalten, Barcode-Scanner (Migration `item_catalog.barcode`, Info.plist-Kamera-Text prüfen).
4. **Listen, Teilen, Konto:** Meine Listen, Neue Liste, Listen-Optionen, Mitglieder & Teilen, Einstellungen, Profil bearbeiten, Konto löschen (Migrationen `favorite_list_id`, `lm_self_delete`, `delete_my_account`, `avatars`, Benachrichtigungs-Spalten).
5. **Einstieg:** Anmelden (E-Mail + Apple), Profil anlegen mit Live-Prüfung, Einladung annehmen inkl. Kaltstart, Leere Liste.
6. **Kategorien:** Migration `categories`, Verwalten mit Ziehen, Bearbeiten, „Sonstiges“ geschützt, Sortierung „Nach Kategorie“ nutzt die Reihenfolge.
7. **Kassenzettel und Preise:** Aufnahme mehrteilig, Vision-OCR `de-DE`, Parser + Zuordnung, Preispunkte (Migration `stores`, `price_points`), Einkauf erledigt, Preisverlauf. Unit-Tests mit 4 Beispiel-Bons.

## 8a. Prüfung je Phase

| Phase | Build | Tests | Pixel-Abgleich (iPhone 17 Pro, `-uiTestFixture -designFixture`) |
|---|---|---|---|
| 1 | grün | – | – |
| 6 | grün | 461 bestanden, 0 fehlgeschlagen (9 neue Unit-Tests; dabei gefunden und behoben: parallele Schreibaufträge bei Favorit und Kategorien konnten beim Server vertauscht ankommen) | ManageCategories, EditCategory: deckungsgleich; Migration 011 angewandt |
| 5 | grün | 450 bestanden, 0 fehlgeschlagen (6 neue Unit-Tests; dabei gefunden: invitePreview fehlte als Protokoll-Anforderung) | SignIn, ProfileSetup, AcceptInvite: deckungsgleich bis auf §9; Migration 010 angewandt und geprüft |
| 4 | grün (auch der vorgemerkte Stand separat gebaut) | 443 bestanden, 0 fehlgeschlagen (10 neue Unit-Tests, 9 neu geschriebene UI-Tests „Meine Listen“) | MyLists, CreateList, ListOptions, ShareMembers, Settings, EditProfile, DeleteAccount: deckungsgleich bis auf §9; Migration 009 angewandt und geprüft |
| 3 | grün | 432 bestanden, 0 fehlgeschlagen (8 neue: Artikel verwalten, Barcode-Suche) | BarcodeScan, ManageItems, NewItem: deckungsgleich; Migration 008 angewandt und geprüft |
| 2 | grün | 423 bestanden, 0 fehlgeschlagen (inkl. 23 UI-Tests, 20 neue Unit-Tests) | Hybrid, MenuOverlay, SortMenu, CopyChoice, CopyDone, DeleteChoice, UndoToast (Light), HybridDark, SortMenuDark, MenuOverlayDark: deckungsgleich bis auf die Punkte in §9 |

## 9. Abweichungen vom Design (werden je Phase ergänzt)

| Screen | Abweichung | Grund |
|---|---|---|
| MenuOverlay ☰ | 6 statt 4 Einträge (Kassenzettel scannen, Import) | Roberts Entscheidung F1/F4; Einstieg nicht gestaltet |
| SignIn | Toast nach „Weiter mit E-Mail“ | Roberts Entscheidung F2; Zwischenzustand nicht gestaltet |
| MenuOverlay ☰ | Eintrag heißt „Import aus Zwischenablage“ | „Aus Zwischenablage importieren“ bricht in der 286-pt-Zeile um |
| SortMenu | Schalter „aus“ nutzt `toggleOff` aus Settings (#DCE5E6 / weiß 14 %) | Design zeigt nur „an“ |
| SortMenu | Zeilenumbruch „Erledigte / nach unten“ statt „Erledigte nach / unten“ | Kante der Textbreite, < 1 pt Unterschied in der Schriftbreite |
| CopyChoice | Vorschau höchstens 8 Zeilen | Design zeigt 2 Zeilen; lange Listen würden das Popover über den Bildschirm schieben |
| DeleteChoice | Untertitel „Offene Artikel bleiben“, wenn Abgehakte vorhanden | Design zeigt nur „Noch nichts abgehakt“ |
| Dock | Weichzeichner (`.ultraThinMaterial`) in Light und Dark | `backdrop-filter` des Designs; ohne ihn scheinen Karten durch die zu 84 % deckende Leiste |
| ManageItems | Filterchips scrollen waagerecht; Chips = „Alle“ + vorhandene Kategorien | Design zeigt feste Chips mit abgeschnittenem Rand |
| ManageItems | Zweite Zeile „Marke · 1 Einheit“ bzw. „Kategorie · 1 Einheit“ | Artikelstamm speichert Einheit, keine Packungsgröße („250 g“ im Design) |
| BarcodeScan | Ohne Kamera (Simulator) Hinweis „Kamera nicht verfügbar“ statt „Kamerabild“; Knopf „Licht“ gedimmt | Platzhalter des Designs |
| BarcodeScan | Mengen-Kreis erhöht per Tippen 1×…9× | Design zeigt nur „1×“ |
| Suchen | Eigene Artikel und Open-Food-Facts in EINER Liste „n Treffer“ | Design SearchResults; vorher zwei Abschnitte |
| ListOptions | „Liste löschen“ mit Untertitel „Mit allen Artikeln, für alle Mitglieder“; bei geteilten Listen „Liste verlassen“ / „Die Liste bleibt für die anderen erhalten“ | Design-Untertitel „Bei geteilten Listen: „Liste verlassen““ ist eine Anmerkung |
| ListOptions | „Umbenennen“ bei geteilten Listen gedimmt | Nur Besitzer dürfen umbenennen (RLS list_update_owner) |
| ListOptions → Löschen | System-Rückfrage vor dem Löschen einer Liste | Löschen ist endgültig und betrifft alle Mitglieder; Design zeigt keinen Zwischenzustand |
| CreateList | „Liste erstellen“ gedimmt, solange der Name leer ist | Design zeigt nur den leeren Anfangszustand |
| CreateList | Sheet rutscht mit der Tastatur nach oben | Design zeigt keine Tastatur |
| ShareMembers | Besitzer kann Mitglieder per Wischen entfernen (roter Knopf wie in „Artikel verwalten“); Inhalt scrollt | Funktion der alten Mitglieder-Ansicht erhalten; Design zeigt ein Mitglied |
| ShareMembers | „Link kopieren“ / ID-Knopf zeigen 2 s „Link kopiert“ bzw. Haken | Rückmeldung nicht gestaltet |
| EditProfile | Unter dem Benutzernamen rote Meldung bei vergeben/ungültig; „Speichern“ erst bei gültigem, freiem Namen | Design zeigt nur den Hinweis |
| Settings | Profilkarte zeigt vollen Namen bzw. Benutzernamen und das Profilfoto | Beispieldaten „Rob“ |
| SignIn | Nutzungsbedingungen/Datenschutzerklärung sind keine Links | Es gibt keine URLs; offener Punkt für Robert |
| SignIn | Nur DEBUG/Simulator: langer Druck auf die Korb-Kachel → Testkonten | Entwickler-Zugang, im Release nicht vorhanden |
| ProfileSetup | Titelumbruch „Wie sollen dich / andere sehen?“ | Textbreite iOS vs. Browser, Code identisch mit Referenz |
| ProfileSetup | Status im Feld: „frei“ (Design) bzw. „vergeben“/„ungültig“/„offline“ in Rot, Ladekreis beim Prüfen; „Los geht’s“ erst bei freiem Namen | Design zeigt nur „frei“ |
| AcceptInvite | Chips entfallen ohne Verbindung (Zahlen unbekannt) | Zahlen kommen aus RPC invite_preview |
| ManageCategories | Mehr als 4 Kategorien → Inhalt scrollt; Ziehen per langem Druck auf die Zeile | Design zeigt 4 Kategorien |
| EditCategory | Dasselbe Sheet als „Neue Kategorie“ (ohne Löschen); bei „Sonstiges“ Name gesperrt, Löschen gedimmt | Nicht gestaltet |
| Liste | Sortierung „Alphabetisch/Zuletzt/Manuell“ zeigt eine flache Liste ohne Kategorie-Kopf | Design zeigt nur „Nach Kategorie“ |
