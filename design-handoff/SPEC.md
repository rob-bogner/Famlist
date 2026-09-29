# Famlist / My List – Design-Spezifikation (Redesign „Hybrid“)

Stand: 27.09.2026 · Quelle: Canvas „Famlist“ (Claude Design). `Design/html/` ist eine 1:1-Kopie des Canvas, siehe `Design/SYNC.md`.

## 1. Wahrheitsquellen – in dieser Reihenfolge

1. **`Design/html/*.dc.html`** – das Design, 1:1 aus dem Canvas (1 CSS-px = 1 pt, Artboard 390 × 844). Maßgeblich bei jeder Abweichung. Canvas und dieser Ordner werden immer gemeinsam geändert.
2. **`MyListUI/`** – SwiftUI-Referenzcode (Stand 24.09.2026) für die Screens mit Eintrag in der Spalte „SwiftUI“ in §2. Neuere Screens gibt es nur als HTML; dort gilt das HTML direkt.
3. **`Design/png/*.png`** – gerenderte Referenzbilder @2x aller Boards (Handy: 780 × 1688 px) für den Sichtvergleich, Stand wie `Design/html/`.

## 2. Screen-Übersicht

Die Reihenfolge folgt der User Journey im Canvas (Seite „User Journey“, Abschnitte 1–7). „Dark“ = eigenes Board `<Datei>Dark`. Kamera- und Vollbild-Screens sind immer dunkel. PNG: `Design/png/<Datei>.png`.

| Bereich | Screen | Design-Datei | Dark | SwiftUI (MyListUI) |
|---|---|---|---|---|
| 1 · Start & Anmeldung | Splash (App-Start) | SplashTomatoesBottom | – | – (nur HTML) |
|  | Anmelden | SignIn | ja | `SignInScreen` |
|  | Anmelden – Link gesendet | SignInLinkSent | ja | – (nur HTML) |
|  | Profil anlegen | ProfileSetup | ja | `ProfileSetupScreen` |
|  | Einladung annehmen | AcceptInvite | ja | `AcceptInviteScreen` |
| 2 · Einkaufsliste | Einkaufsliste | Hybrid | ja | `ListScreen(state: .normal)` |
|  | Liste – Kopf kompakt (beim Scrollen) | ListCompact | ja | – (nur HTML) |
|  | Leere Liste | EmptyList | ja | `ListScreen(state: .empty)` |
|  | Liste filtern (Suchleiste oben) | SearchInline | ja | – (nur HTML) |
|  | Tab „Offen“ – alles erledigt | FilterOpenEmpty | ja | – (nur HTML) |
|  | Tab „Erledigt“ – noch nichts abgehakt | FilterDoneEmpty | ja | – (nur HTML) |
|  | Abhaken (nach rechts wischen) | SwipeCheck | ja | – (nur HTML) |
|  | Abgehakt – zurück auf die Liste (nach links wischen) | Checked | ja | `ListScreen(state: .checked)` |
|  | Abgehakt löschen (nach rechts wischen) | SwipeDelete | ja | – (nur HTML) |
|  | Wisch-Aktionen offen (nach links wischen) | SwipeActions | ja | `ListScreen(state: .swipe)` |
|  | Artikel nicht verfügbar | ItemUnavailable | ja | – (nur HTML) |
|  | Gelöscht – Rückgängig | UndoToast | ja | `UndoToastScreen` |
|  | Sync fehlgeschlagen | ItemSyncFailed | ja | – (nur HTML) |
|  | Sync fehlgeschlagen – erneut versuchen? | ItemSyncFailedDialog | ja | – (nur HTML) |
| 3 · Artikel hinzufügen & bearbeiten | Artikel hinzufügen (Plus → Eingabe unten) | AddInline | ja | – (nur HTML) |
|  | Artikel hinzufügen – keine Treffer | AddInlineNoResults | ja | – (nur HTML) |
|  | Neuer Artikel (Produktdetails, leer) | ProductNew | ja | – (nur HTML) |
|  | Foto hinzufügen – Quelle wählen | PhotoSourceDialog | ja | – (nur HTML) |
|  | Barcode-Scanner (Kamera, immer dunkel) | BarcodeScan | – | `BarcodeScanScreen` |
|  | Barcode – Artikel wird gesucht | BarcodeLookup | – | – (nur HTML) |
|  | Barcode – Kamera nicht verfügbar | BarcodeNoCamera | – | – (nur HTML) |
|  | Produktdetails (Tipp auf das Artikelbild) | ProductDetail | ja | – (nur HTML) |
|  | Produktdetails – eigenes Foto füllt den Kopf | ProductDetailPhoto | ja | – (nur HTML) |
|  | Artikel bearbeiten (Produktdetails) | ProductDetailEdit | ja | – (nur HTML) |
|  | Artikel bearbeiten – Menge eintippen | ProductDetailAmount | ja | – (nur HTML) |
|  | Preisverlauf | PriceHistory | ja | `PriceHistoryScreen` |
| 4 · Aktionsleiste (Dock) | Sortieren | SortMenu | ja | `SortMenuScreen` |
|  | In Zwischenablage kopieren | CopyChoice | ja | `CopyChoiceScreen` |
|  | Kopiert – Bestätigung | CopyDone | ja | `CopyDoneScreen` |
|  | Artikel löschen – Auswahl | DeleteChoice | ja | `DeleteChoiceScreen` |
| 5 · Menü & Listen | Kontext-Menü | MenuOverlay | ja | `MenuOverlayScreen` |
|  | Meine Listen | MyLists | ja | `MyListsScreen` |
|  | Meine Listen – noch keine Liste | MyListsEmpty | ja | – (nur HTML) |
|  | Meine Listen – nach links wischen (Löschen, Umbenennen, Duplizieren, Mitglieder) | MyListsSwipeLeft | ja | – (nur HTML) |
|  | Meine Listen – nach rechts wischen (Favorit) | MyListsSwipeRight | ja | – (nur HTML) |
|  | Meine Listen – Liste gelöscht, Rückgängig | MyListsUndo | ja | – (nur HTML) |
|  | Neue Liste | CreateList | ja | `CreateListScreen` |
|  | Liste umbenennen | ListName | ja | – (nur HTML) |
|  | Listen-Optionen | ListOptions | ja | `ListOptionsScreen` |
|  | Liste löschen – Bestätigung | DeleteListDialog | ja | – (nur HTML) |
|  | Letzte Liste – kann nicht gelöscht werden | LastListError | ja | – (nur HTML) |
|  | Mitglieder & Teilen | ShareMembers | ja | `ShareMembersScreen` |
|  | Aus Zwischenablage importieren | ClipboardImport | ja | – (nur HTML) |
|  | Artikel verwalten | ManageItems | ja | `ManageItemsScreen` |
|  | Kategorien verwalten | ManageCategories | ja | `ManageCategoriesScreen` |
|  | Kategorie bearbeiten | EditCategory | ja | `EditCategoryScreen` |
| 6 · Einkauf abschließen | Einkauf erledigt | ShoppingDone | ja | `ShoppingDoneScreen` |
|  | Einkauf erledigt – ohne Kassenzettel | ShoppingDoneScan | ja | – (nur HTML) |
|  | Kassenzettel fotografieren (Kamera, immer dunkel) | ReceiptCapture | – | `ReceiptCaptureScreen` |
|  | Kassenzettel wird gelesen | ReceiptReading | ja | – (nur HTML) |
|  | Kassenzettel prüfen | ReceiptReview | ja | `ReceiptReviewScreen` |
|  | Bon-Zeile zuordnen | ReceiptAssignDialog | ja | – (nur HTML) |
|  | Laden ändern | ReceiptStoreAlert | ja | – (nur HTML) |
|  | Kassenzettel prüfen – nicht gefunden | ReceiptReviewMissing | ja | – (nur HTML) |
|  | Artikelpreise aktualisieren? | ReceiptPriceAlert | ja | – (nur HTML) |
| 7 · Einstellungen & Konto | Einstellungen | Settings | ja | `SettingsScreen` |
|  | Abmelden – ungesendete Änderungen | SignOutDialog | ja | – (nur HTML) |
|  | Profil bearbeiten | EditProfile | ja | `EditProfileScreen` |
|  | Kassenzettel-Archiv | ReceiptArchive | ja | – (nur HTML) |
|  | Kassenzettel-Archiv – leer | ReceiptArchiveEmpty | ja | – (nur HTML) |
|  | Kassenzettel – Detail | ReceiptDetail | ja | – (nur HTML) |
|  | Kassenzettel – Vollbild (immer dunkel) | ReceiptFullscreen | – | – (nur HTML) |
|  | Kassenzettel löschen – Bestätigung | ReceiptDeleteDialog | ja | – (nur HTML) |
|  | Konto löschen | DeleteAccount | ja | `DeleteAccountScreen` |
|  | Konto wiederherstellen (nach Anmeldung) | RestoreAccount | ja | – (nur HTML) |
|  | Wiederherstellen – lädt | RestoreAccountLoading | ja | – (nur HTML) |
|  | Wiederherstellen – offline | RestoreAccountOffline | ja | – (nur HTML) |
|  | Jetzt endgültig löschen | RestorePurgeDialog | ja | – (nur HTML) |
|  | Hinweis für Listenbesitzer | MemberDeletedToast | ja | – (nur HTML) |
|  | Mitglieder – Konto gelöscht | ShareMembersArchived | ja | – (nur HTML) |
|  | Gelöschtes Mitglied entfernen | ArchivedMemberRemove | ja | – (nur HTML) |
| Apple Watch | Watch – Listen | WatchLists | – | – |
|  | Watch – Einkaufsliste | WatchList | – | – |
|  | Watch – Artikel | WatchItem | – | – |
|  | Watch – Artikel hinzufügen | WatchAdd | – | – |
|  | Watch – Alles erledigt | WatchDone | – | – |
|  | Watch – Zifferblatt & Smart Stack | WatchFace | – | – |
| Bausteine & Referenz | Dock | Dock | – | `DockView(active:pill:)` |
|  | Dock – alle Zustände | DockStates | – | `DockView(active:pill:)` |
|  | Kategorie-Icons (60) | CategoryIcons | – | – |
|  | Zielstruktur (Schritt 1) | StructureMap | – | – |
|  | Schieben zum Löschen – Zustände | SlideToDelete | ja | – |
| Produktbilder | Obst – Stil & Regeln (Phase 1) | FruitStyle | – | – |
|  | Obst in der Einkaufsliste | FruitList | ja | – |
|  | Obst – alle 38 Produktbilder | FruitCatalog | ja | – |
|  | Obst in den Vorschlägen (Plus) | FruitAdd | ja | – |
|  | Obst – Vergleich in UI-Größe | FruitSizes | – | – |
| Einkaufsdaten & Auswertung (freigegeben 28.09.2026, umgesetzt 29.09.2026, RECEIPT_INSIGHTS_PROMPT.md) | Kassenzettel-Archiv – Einstieg Auswertung | ReceiptArchiveInsights | ja | `ReceiptArchiveSheet`, `ReceiptInsightsCard` |
|  | Kassenzettel – Detail mit Metadaten | ReceiptDetailMeta | ja | `ReceiptDetailSheet` |
|  | Auswertung – Ausgaben | InsightSpend | ja | `ReceiptInsightsSheet`, `SpendInsightsView` |
|  | Auswertung – Verbrauch | InsightUsage | ja | `ReceiptInsightsSheet`, `UsageInsightsView` |


`Design/png/StructureMap.png` zeigt die Zielstruktur mit allen Workflows. Frühere Varianten liegen im Canvas auf der Seite „Archiv“ (Main, HybridCompact, HybridCompactTop, SplashBrand, seit 28.09.2026 auch NewItem, EditItem, EditItemAmount, ProductImage) und gelten nicht mehr.

## 3. Navigation und Workflows

1. **Artikel hinzufügen**
   - Der **Plus-Button (FAB)** öffnet die Eingabe unten über der Tastatur (AddInline). Das Popup mit Vorschlägen wächst nach oben; jeder Vorschlag hat einen runden Glas-„+“.
   - Senden/Return fügt den besten Treffer hinzu. Kein Treffer → „„…“ als neuen Artikel anlegen“ → Neuer Artikel (Name vorbefüllt), siehe AddInlineNoResults.
   - **Produktdetails** (ProductDetail, seit 28.09.2026) ist EIN Screen für neu, ansehen und bearbeiten: Sheet (790 hoch, oben Radius 34, Griff, Herunterziehen schließt) über der abgedunkelten Liste, oben großes Produktbild (330, unten Radius 40), ✕ oben rechts (14 / 16), Glas-Stift „Bearbeiten“ unten rechts am Bild (nur Ansehen; beim Bearbeiten sitzt dort der Kamera-Knopf „Bild ändern“). Darunter Name + Marke links, aktueller Preis rechts, Karten Kategorie · Maßeinheit · Menge in der Liste · Preisverlauf, dann Beschreibung.
   - Tipp auf das Artikelbild in der Liste → Ansehen; Stift → dieselben Stellen werden Eingabefelder (ProductDetailEdit), „Speichern“ → zurück zu Ansehen. Wischaktion „Bearbeiten“ öffnet direkt das Bearbeiten. Neuer Artikel = ProductNew (leere Felder, gestrichelte Kachel „Foto hinzufügen“, „Zur Liste hinzufügen“).
   - Bild im Kopf: Bilder aus der Produktbibliothek (freigestellt, z. B. Obst) stehen mittig mit 300 × 300; ein eigenes Foto füllt den ganzen Kopf (390 × 330, unten Radius 40) mit leichtem Schatten oben für Griff und ✕ (ProductDetailPhoto).
   - Kategorie und Maßeinheit sind beim Bearbeiten Auswahlmenüs, die Menge ein kompakter Stepper in der Karte (Eintippen: ProductDetailAmount mit Schnellwahl über dem Ziffernblock).
   - Die Suchleiste oben **filtert nur die Artikel der aktuellen Liste** (SearchInline; Name und Marke, ohne Groß-/Kleinschreibung und Akzente). Findet der Filter nichts, bietet er „… hinzufügen“ an. Während Filter oder Eingabe offen sind, ist das Dock ausgeblendet.
2. **Per Barcode**
   - Scan-Knopf in der Eingabe unten → Barcode-Scanner.
   - Erkannter Artikel → „Zur Liste hinzufügen“. Während der Suche „Artikel wird gesucht …“ (BarcodeLookup); ohne Kamera Hinweis „Kamera nicht verfügbar“ (BarcodeNoCamera). Unbekannter Code → Neuer Artikel (vorbefüllt).
3. **Menge**
   - Stepper plus direktes Eintippen der Zahl; beim Tippen ersetzt eine Schnellwahl-Leiste den Hauptknopf (EditItemAmount).
   - Schrittweite je Einheit: g/ml 50, kg/l/m 0,1 (gedrückt halten: 1), sonst 1. Kommazahlen sind erlaubt (1,5 kg). Grenzen 1 … 9999, bei 0,1-Schritten ab 0,1.
   - Hinweis: Die App kann Kommazahlen seit 26.09.2026; das Board EditItemAmount zeigt noch eine Zifferntastatur ohne Komma. Design-Nachtrag offen – bis dahin gilt das Verhalten der App.
4. **Einkaufen**
   - Nach rechts wischen hakt ab (SwipeCheck). Ein abgehakter Artikel: nach rechts wischen löscht ihn (SwipeDelete, rot „Löschen“ mit Mülleimer), nach links „Zurück auf die Liste“ (Checked).
   - Nach links wischen zeigt runde Glas-Aktionsknöpfe (SwipeActions, 56 pt).
   - Zustände einer Karte: „Nicht verfügbar“ (ItemUnavailable), „Sync fehlgeschlagen“ mit Rückfrage (ItemSyncFailed, ItemSyncFailedDialog).
   - Fortschritt im Hero: „x von y Artikeln“ und Prozent. Beim Scrollen klappt der Kopf kompakt zusammen (ListCompact).
   - Tabs Alle / Offen / Erledigt filtern; leere Tabs zeigen eigene Hinweise (FilterOpenEmpty, FilterDoneEmpty).
   - Sektionskopf „Alle abhaken ›“ gilt pro Kategorie.
5. **Dock (untere Leiste)**
   - Es ist immer genau ein Button gewählt. Er ist eine Pille mit Highlight und Beschriftung; die anderen Buttons sind nur 44-pt-Icons.
   - Ruhezustand: „Alle abhaken“. Sind alle Artikel erledigt, heißt die Pille „Zurücksetzen“ (alle wieder offen).
   - **Sortieren** öffnet ein Popover:
     - Nach Kategorie (Ladenweg), Alphabetisch, Zuletzt hinzugefügt, Manuell
     - Schalter „Erledigte nach unten“
     - Die Einstellung gilt pro Liste und wird gespeichert.
   - **Kopieren** öffnet ein Popover:
     - Offene Artikel / Alle Artikel, mit Textvorschau
     - Danach zeigt die Pille 2 s lang „Kopiert“ mit Haken, dazu der Toast „Liste kopiert“.
     - Textformat: Listenname in der ersten Zeile, dann `• Name · Menge Einheit` je Artikel.
   - **Löschen** öffnet ein Popover:
     - Nur abgehakte / Alle Artikel
     - Danach der Toast „x Artikel gelöscht“ mit Rückgängig, blendet nach 5 s aus. Kein Bestätigungsdialog.
     - Die Pille ist rot.
   - Die gewählte Pille wandert animiert zum angetippten Button, z. B. mit `matchedGeometryEffect`.
   - Beim Schließen eines Popovers springt die Auswahl zurück auf „Alle abhaken“.
   - **Leere Liste:** Abhaken, Kopieren und Löschen sind gedimmt und inaktiv. Sortieren bleibt aktiv.
6. **Kontext-Menü ☰** (oben rechts, Glas-Knopf): Mitglieder & Teilen, Artikel verwalten, Kategorien verwalten, Kassenzettel scannen, Aus Zwischenablage importieren (ClipboardImport), Einstellungen.
7. **Listen**
   - Tipp auf den Titel „My List ⌄“ → Meine Listen: wechseln, neue Liste erstellen. Ohne Listen: MyListsEmpty.
   - Listen-Karten wischen (zusätzlich zum Kontextmenü bei langem Druck, wie bei Artikeln): nach rechts = Favorit an/aus (Glas-Kreis gelb, durchwischen löst direkt aus); nach links = Aktionen Löschen (rot), Umbenennen (blau), Duplizieren (türkis), Mitglieder (violett) – Kreise 48, Spalte 70, Beschriftung 11/600 (MyListsSwipeLeft/-Right). Geteilte Listen: statt „Löschen“ „Verlassen“. Löschen per Wischen ohne Rückfrage, dafür Hinweis „„<Liste>“ gelöscht“ mit „Rückgängig“ (5 s, Restzeit-Balken; wie UndoToast, 14 über „Neue Liste erstellen“) – MyListsUndo. Auch nach dem Löschen über das Kontextmenü erscheint „Rückgängig“. Letzte Liste: Hinweis wie LastListError.
   - **Langer Druck** auf eine Liste → **Listen-Optionen**: Umbenennen (ListName), Duplizieren, Favorit, Mitglieder & Teilen, Liste löschen mit Bestätigung (DeleteListDialog; bei geteilten Listen „Liste verlassen“). Die letzte Liste kann nicht gelöscht werden (LastListError).
   - Dieselben Aktionen gibt es seit 29.09.2026 zusätzlich per Wischen (siehe unten).
8. **Teilen**
   - Mitglieder & Teilen zeigt die Mitgliederliste und hat „Einladungslink teilen“ (Share Sheet) und „Link kopieren“. Dazu die öffentliche ID mit Kopier-Knopf.
   - Hat ein Mitglied sein Konto gelöscht, sieht der Besitzer einmalig einen Hinweis in der Liste (MemberDeletedToast). In „Mitglieder“ steht die Person bis zum Ende der Frist ausgegraut als „Konto gelöscht · bis <Datum> wiederherstellbar“ mit „Entfernen“ (ShareMembersArchived) und Bestätigung (ArchivedMemberRemove). Wer nicht entfernt wird, ist nach dem Wiederherstellen automatisch wieder Mitglied.
9. **Einladung**
   - Einladungslink (Deep Link) → falls nötig Anmelden → Profil anlegen → Einladung annehmen oder ablehnen → Liste öffnet sich.
10. **Konto**
    - ☰ → Einstellungen. Oben ist eine Profilkarte; sie ist der **einzige** Weg zu Profil bearbeiten.
    - Erscheinungsbild: System / Hell / Dunkel. Benachrichtigungen: geteilte Listen, Einladungen.
    - Abmelden; mit ungesendeten Änderungen fragt eine Aktionskarte nach (SignOutDialog).
    - **Konto löschen** (Pflicht für den App Store): archiviert das Konto 60 Tage. Geteilte Listen verschwinden sofort bei allen Mitgliedern, aus fremden Listen wird man entfernt. Details: `ACCOUNT_ARCHIVE_PROMPT.md`.
    - **Konto wiederherstellen:** Wer sich innerhalb der 60 Tage anmeldet, sieht RestoreAccount (Laden: RestoreAccountLoading, offline: RestoreAccountOffline) mit „Konto wiederherstellen“, „Abmelden“ und „Endgültig löschen“ (Bestätigung RestorePurgeDialog).
11. **Artikel verwalten**
    - Zeigt alle gespeicherten Artikel (Artikelstamm), mit Suche und Kategorie-Filterchips.
    - Pfeil → Artikel bearbeiten (Produktdetails im Bearbeiten-Modus, ohne Menge und Preisverlauf). Wischen → löschen.
12. **Kategorien**
    - Die Reihenfolge der Kategorien entspricht dem Ladenweg. Umsortieren per Ziehen.
    - Tippen → Kategorie bearbeiten: Name, Icon (60 Icons, CategoryIcons), löschen.
    - „Sonstiges“ ist die Standardkategorie und kann nicht gelöscht werden. Artikel einer gelöschten Kategorie wandern nach „Sonstiges“.
13. **Kassenzettel und Preise**
    - Sind alle Artikel abgehakt: Einkauf erledigt (ShoppingDone), ohne Kassenzettel zuerst „Kassenzettel scannen?“ (ShoppingDoneScan).
    - Kassenzettel fotografieren; lange Bons in mehreren Teilen, ein Zähler zeigt die Anzahl der Aufnahmen. Danach „Kassenzettel wird gelesen“ (ReceiptReading).
    - Kassenzettel prüfen: erkannte Positionen mit Preisen, automatische Zuordnung („Zugeordnet“, „Zuordnung prüfen“, „Neuer Artikel?“), Laden und Datum, Summe. Tippen auf eine Position → Zuordnen (ReceiptAssignDialog); Laden ändern (ReceiptStoreAlert); Artikel der Liste, die nicht auf dem Bon stehen (ReceiptReviewMissing).
    - „Preise speichern“ legt Preispunkte an. Weicht ein Bon-Preis vom gespeicherten Artikelpreis ab, fragt die App nach (ReceiptPriceAlert).
    - Kassenzettel-Archiv (KASSENZETTEL_ARCHIV.md): Einstellungen → „Gespeicherte Kassenzettel“ (ReceiptArchive, leer: ReceiptArchiveEmpty); Detail mit Fotos, Summe, Teilen, Löschen mit Bestätigung (ReceiptDetail, ReceiptFullscreen, ReceiptDeleteDialog). Preise bleiben beim Löschen erhalten.
    - Einkaufsdaten & Auswertung (RECEIPT_INSIGHTS_PROMPT.md): Archiv oben Karte „Auswertung <Monat>“ → Sheet „Auswertung“ mit Reitern Ausgaben · Verbrauch und Monatswechsel (InsightSpend, InsightUsage). Detail zeigt Metadaten (Ort, Datum, Uhrzeit, Dauer, Artikel, Wert) und Reiter „Artikel“ · „Bon-Foto“ (ReceiptDetailMeta); Tipp auf einen Artikel → Preisverlauf.
    - Preisverlauf pro Artikel: Tiefster, Schnitt und Höchster Preis, Diagramm über die Monate, Liste „Nach Laden“ mit Markierung „GÜNSTIGSTER“. Erreichbar über die Karte „Preisverlauf“ in Produktdetails.
14. **Anmelden**
    - E-Mail (Magic Link, danach SignInLinkSent) oder „Mit Apple anmelden“.
    - Dann Profil anlegen: Foto, Benutzername mit Live-Prüfung „frei“, optional der Name.
15. **Produktbilder**
    - Artikel ohne eigenes Foto zeigen ein Produktbild aus der Bibliothek in der vorhandenen Kachel (64 pt in Karten, 40 pt in Vorschlägen).
    - Obst ist fertig: 38 SVG-Bilder unter `Design/html/assets/fruit/fruit.<id>.svg` (IDs englisch, z. B. `fruit.banana`). Stil und Regeln: FruitStyle; Übersicht: FruitCatalog; Beispiele in Liste und Vorschlägen: FruitList, FruitAdd.

## 4. Designregeln

- **Farben:**
  - Akzent: Light #0FA3AE, Dark #1FC2CC.
  - Abgeleitete Töne werden in `AccentScale` berechnet, nie hart codiert:
    - light = Mischung Richtung Weiß 0,32
    - deep = Mischung Richtung Schwarz 0,4 (Light) / 0,5 (Dark)
    - deeper = Mischung Richtung Schwarz 0,6
- **Schriften:** Outfit (Titel) und DM Sans (Text), beide als Variable Fonts. Einrichtung siehe `MyListUI/README.md`.
- **Knöpfe – ausnahmslos im Glas-Stil wie der FAB:**
  - Kreise und Pillen mit radialem bzw. senkrechtem Verlauf (Licht oben links bei 32 % / 22 %), Glanz oben und Lichtsaum unten, Maße proportional zum FAB 64.
  - Stile (`GlassStyleTokens`): Akzent, Neutral, Neutral-dunkel (Kamera/Fotos), Gefahr (rot), Apple (schwarz in Light, weiß in Dark).
  - Gilt auch für ☰ und Filter im Listenkopf, Schließen-Knöpfe, Wisch-Aktionen und „Mit Apple anmelden“. Keine iOS-Systemdialoge (confirmationDialog/alert): Rückfragen und Auswahl erscheinen als **Aktionskarte** (seit 29.09.2026) – Karte unten (links/rechts 12, unten 30, Radius 30, Fläche/Rand/Schatten wie „Artikel erkannt“ im Barcode-Scanner, Abdunkelung ohne Blur), Symbol-Kachel 48 (Radius 16, Ton: Gefahr/Warnung/Info), Titel Outfit 19/600, Text 14 sub, darunter Glas-Knöpfe: Hauptaktion CTA; endgültiges Löschen/Entfernen als **Schieben zum Löschen** (Spur 56, Radius 28, Gefahr-Ton, roter Glas-Knopf 48 mit Mülleimer, Text mittig mit »»», ab 85 % ausgelöst, sonst zurückfedern; VoiceOver: Doppeltippen; Board SlideToDelete unter „Bausteine“ – gilt auch für Konto löschen und Jetzt endgültig löschen), weitere Optionen neutrale Glas-Pillen, kein „Abbrechen“-Knopf: Schließen über den neutralen Glas-Knopf ✕ (40) oben rechts in der Karte, Tipp auf die Abdunkelung oder VoiceOver „Zurück“ (Ausnahme: „Artikelpreise aktualisieren?“ ohne ✕ – beide Wege speichern). Gilt auch für „Konto löschen“ und „Jetzt endgültig löschen“ (✕ oben rechts, 14 / 14). Boards: ItemSyncFailedDialog, PhotoSourceDialog, DeleteListDialog, ReceiptAssignDialog, ReceiptPriceAlert, SignOutDialog, ReceiptStoreAlert, ReceiptDeleteDialog, ArchivedMemberRemove.
- **Dock:** in Light **und** Dark dunkles Glas. Keine Lichtkante an der Pille.
- **Sheets:**
  - Oberer Radius 34, Griff 40 × 5.
  - Titel in Outfit 22/600.
  - Schließen-Knopf rund, 44 pt, Glas neutral.
  - Hintergrund abgedunkelt mit Blur.
- **Popover über dem Dock:**
  - Breite 270, links 20, Unterkante 108 pt über dem Bildschirmrand.
  - Die Zeiger-Raute zeigt auf die Mitte der gewählten Pille.
- **Produktbilder („Detailed Volume“):** detaillierte SVG ohne Filter/Masken (Xcode-tauglich), Zeichenfläche 128, transparent, Sicherheitsrand 12, Standlinie y 112, Licht oben links, sichtbare Fläche 26–29 % (schlanke Formen 22–25 %). Ein Bild für Light und Dark; den Hintergrund liefert die Kachel.
- **Geometrie:**
  - Inhalt ab 62 pt von oben.
  - Das Dock sitzt 34 pt über der Unterkante.
  - Auf breiteren Geräten wächst nur die Breite.

## 5. Noch nicht gestaltet – NICHT umsetzen

- Avatar „wer hat was“ an Artikeln
- Produktbilder außer Obst (Gemüse, Milchprodukte …) – kommen kategorieweise im Stil von FruitStyle.
- Nährwerte je Artikel (ReceiptItemNutrition) und Auswertung Ernährung (InsightNutrition) – Entwurf liegt im Canvas auf der Seite „Archiv“, noch nicht freigegeben. Quellen später: Open Food Facts (Barcode) + BLS 4.0 (allgemeine Lebensmittel).

Diese Punkte kommen später mit eigenem Design. Bis dahin gilt: kein eigenes UI dafür erfinden.

**Von Robert freigegeben (28.09.2026) – Kassenzettel wie ein Dokumentenscanner:**
Jede Aufnahme wird automatisch auf den Bon zugeschnitten (ohne neues UI). Dazu gestaltet und umgesetzt:
- ReceiptCaptureLive (Bon erkannt, Auto), ReceiptCaptureLiveManual (Bon erkannt, Manuell), ReceiptCaptureLiveSearch
  (kein Bon im Bild): Live-Rahmen um den Bon, Hinweis-Pille, Ring am Auslöser füllt sich bis zur Auto-Aufnahme,
  Schalter „Auto“/„Manuell“ rechts neben den Aufnahmen.
- Tippen auf ein Vorschaubild öffnet das Vollbild (ReceiptFullscreenCrop) mit der Pille „Ecken anpassen“.
- ReceiptCropEdit, ReceiptCropEditDrag: „Ecken anpassen“ – vier Griffe, Lupe beim Ziehen, „Ganzes Foto“ verwirft
  den Zuschnitt, „Übernehmen“ speichert ihn; ✕ führt ohne Änderung zurück zum Vollbild.

**Von Robert gewünscht (28.09.2026), nicht gestaltet:** Menü ☰ → „Gespeicherte Kassenzettel“ (unter „Kassenzettel
scannen“, Icon „Fotos“ aus ReceiptCapture) öffnet das Archiv direkt über der Liste; „Zurück“ schließt es dann.
Der Bon speichert seine Positionen (Migration 029); das Bon-Detail zeigt sie seit 29.09.2026 mit Einkaufsdaten (ReceiptDetailMeta, RECEIPT_INSIGHTS_PLAN.md).

**Von Robert freigegeben (25.09.2026), obwohl ursprünglich nicht gestaltet:** Live-Gesamtkosten in der Fortschrittskarte und
Preis auf jeder Artikelkarte (abschaltbar: Einstellungen → „Preise anzeigen“). Der Link „Preisverlauf“ in „Artikel bearbeiten“
ist inzwischen gestaltet (EditItem). Umsetzung und Abweichungen: PLAN.md §9.

**Apple Watch (26.09.2026, WATCH_PROMPT.md):** Nicht gestaltet und deshalb schlicht im vorhandenen Stil
umgesetzt (WATCH_PLAN.md §5): Anmeldung der Uhr über das iPhone („Verbinde mit dem iPhone …“, „Öffne Famlist
auf dem iPhone …“), leere Liste, Hinweis auf wartende Änderungen, Status „Keine Artikel“, der Weg zum Screen
„Listen“ (Titel antippen) und die Anzeige bei großer Textgröße. Abweichungen: PLAN.md §9. Ein eigenes Design
dafür ersetzt diese Übergangslösungen.
