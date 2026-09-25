# Famlist / My List – Design-Spezifikation (Redesign „Hybrid“)

Stand: 24.09.2026 · Quelle: Canvas „My List – Redesign“ (Claude Design)

## 1. Wahrheitsquellen – in dieser Reihenfolge

1. **`MyListUI/`** – SwiftUI-Referenzcode aller Screens. Aus dem HTML übersetzt, pixelgenau (1 CSS-px = 1 pt, Artboard 390 × 844). **Diese Views werden übernommen, nicht nachgebaut.**
2. **`Design/html/*.dc.html`** – Original-Design als HTML/CSS. Maßgeblich, wenn der SwiftUI-Code und das Design voneinander abweichen.
3. **`Design/png/*.png`** – gerenderte Referenzbilder @2x (780 × 1688 px) für den Sichtvergleich.

## 2. Screen-Übersicht

Jede Zeile hat eine Light- und eine Dark-Variante, außer bei den Kamera-Screens. PNG: `Design/png/<Datei>.png` und `<Datei>Dark.png`.

| Bereich | Screen | Design-Datei | SwiftUI |
|---|---|---|---|
| Liste | Liste (Hybrid) | Hybrid | `ListScreen(state: .normal)` |
| | Abgehakt | Checked | `ListScreen(state: .checked)` |
| | Wisch-Aktionen | SwipeActions | `ListScreen(state: .swipe)` |
| | Leere Liste | EmptyList | `ListScreen(state: .empty)` |
| | Dock (untere Leiste), 7 Zustände | Dock, DockStates | `DockView(active:pill:)` |
| | Kontext-Menü ☰ | MenuOverlay | `MenuOverlayScreen` |
| | Sortieren | SortMenu | `SortMenuScreen` |
| | Zwischenablage: Auswahl | CopyChoice | `CopyChoiceScreen` |
| | Zwischenablage: Kopiert | CopyDone | `CopyDoneScreen` |
| | Artikel löschen: Auswahl | DeleteChoice | `DeleteChoiceScreen` |
| | Gelöscht, Rückgängig | UndoToast | `UndoToastScreen` |
| Artikel | Suchen (leer / Treffer) | SearchEmpty / SearchResults | `SearchEmptyScreen` / `SearchResultsScreen` |
| | Neuer Artikel | NewItem | `NewItemScreen` |
| | Artikel bearbeiten | EditItem | `EditItemScreen` |
| | Produktbild | ProductImage | `ProductImageScreen` |
| | Artikel verwalten | ManageItems | `ManageItemsScreen` |
| | Barcode-Scanner (nur dunkel) | BarcodeScan | `BarcodeScanScreen` |
| | Preisverlauf | PriceHistory | `PriceHistoryScreen` |
| Listen | Meine Listen | MyLists | `MyListsScreen` |
| | Neue Liste | CreateList | `CreateListScreen` |
| | Listen-Optionen | ListOptions | `ListOptionsScreen` |
| | Mitglieder & Teilen | ShareMembers | `ShareMembersScreen` |
| Konto | Einstellungen | Settings | `SettingsScreen` |
| | Profil bearbeiten | EditProfile | `EditProfileScreen` |
| | Konto löschen | DeleteAccount | `DeleteAccountScreen` |
| Einstieg | Anmelden | SignIn | `SignInScreen` |
| | Profil anlegen | ProfileSetup | `ProfileSetupScreen` |
| | Einladung annehmen | AcceptInvite | `AcceptInviteScreen` |
| Kategorien | Kategorien verwalten | ManageCategories | `ManageCategoriesScreen` |
| | Kategorie bearbeiten | EditCategory | `EditCategoryScreen` |
| Kassenzettel | Kassenzettel fotografieren (nur dunkel) | ReceiptCapture | `ReceiptCaptureScreen` |
| | Kassenzettel prüfen | ReceiptReview | `ReceiptReviewScreen` |
| | Einkauf erledigt | ShoppingDone | `ShoppingDoneScreen` |

`Design/png/StructureMap.png` zeigt die Zielstruktur mit allen Workflows.

## 3. Navigation und Workflows

1. **Artikel hinzufügen**
   - Über das Suchfeld: Treffer → „+“, oder „Neu anlegen: „…““ → Neuer Artikel (Name vorbefüllt).
   - Der **Plus-Button (FAB)** öffnet direkt **Neuer Artikel**.
2. **Per Barcode**
   - Scan-Knopf im Suchfeld → Barcode-Scanner.
   - Erkannter Artikel → „Zur Liste hinzufügen“. Unbekannter Code → Neuer Artikel (vorbefüllt).
3. **Einkaufen**
   - Artikel abhaken. Ein abgehakter Artikel zeigt kurz „Zurück“ (Rückgängig).
   - Fortschritt im Hero: „x von y Artikeln“ und Prozent.
   - Tabs Alle / Offen / Erledigt filtern.
   - Sektionskopf „Alle abhaken ›“ gilt pro Kategorie.
4. **Dock (untere Leiste)**
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
5. **Kontext-Menü ☰** (oben rechts) enthält nur:
   - Mitglieder & Teilen (aktuelle Liste)
   - Artikel verwalten
   - Kategorien verwalten
   - Einstellungen
6. **Listen**
   - Tipp auf den Titel „My List ⌄“ → Meine Listen: wechseln, neue Liste erstellen.
   - **Langer Druck** auf eine Liste → **Listen-Optionen**: Umbenennen, Duplizieren, Favorit, Mitglieder & Teilen, Liste löschen (bei geteilten Listen „Liste verlassen“).
   - Alle Listen-Aktionen gibt es **nur** dort.
7. **Teilen**
   - Mitglieder & Teilen zeigt die Mitgliederliste und hat „Einladungslink teilen“ (Share Sheet) und „Link kopieren“.
   - Dazu die öffentliche ID mit Kopier-Knopf.
8. **Einladung**
   - Einladungslink (Universal Link / Deep Link) → falls nötig Anmelden → Profil anlegen → Einladung annehmen oder ablehnen → Liste öffnet sich.
9. **Konto**
   - ☰ → Einstellungen. Oben ist eine Profilkarte; sie ist der **einzige** Weg zu Profil bearbeiten.
   - Erscheinungsbild: System / Hell / Dunkel.
   - Benachrichtigungen: geteilte Listen, Einladungen.
   - Abmelden.
   - Konto löschen mit Bestätigungssheet. Das ist Pflicht für den App Store.
10. **Artikel verwalten**
    - Zeigt alle gespeicherten Artikel (Artikelstamm), mit Suche und Kategorie-Filterchips.
    - Tippen → Artikel bearbeiten. Wischen → löschen.
11. **Kategorien**
    - Die Reihenfolge der Kategorien entspricht dem Ladenweg. Umsortieren per Ziehen.
    - Tippen → Kategorie bearbeiten: Name, Icon, löschen.
    - „Sonstiges“ ist die Standardkategorie und kann nicht gelöscht werden. Artikel einer gelöschten Kategorie wandern nach „Sonstiges“.
12. **Kassenzettel und Preise**
    - Nach dem Einkauf den Kassenzettel fotografieren. Lange Bons in mehreren Teilen aufnehmen; ein Zähler zeigt die Anzahl der Aufnahmen.
    - Kassenzettel prüfen:
      - Erkannte Positionen mit Preisen
      - Automatische Zuordnung zu Artikeln mit Status „Zugeordnet“, „Zuordnung prüfen“ oder „Neuer Artikel?“
      - Laden und Datum
      - Summe
    - „Preise speichern“ legt Preispunkte an.
    - Einkauf erledigt zeigt die Summe und die Anzahl gespeicherter Preise. Dann „Abgehakte löschen & fertig“ oder „Liste behalten“.
    - Preisverlauf pro Artikel:
      - Tiefster, Schnitt und Höchster Preis
      - Diagramm über die Monate
      - Liste „Nach Laden“ mit Markierung „GÜNSTIGSTER“
13. **Anmelden**
    - E-Mail oder „Mit Apple anmelden“.
    - Dann Profil anlegen: Foto, Benutzername mit Live-Prüfung „frei“, optional der Name.

## 4. Designregeln

- **Farben:**
  - Akzent: Light #0FA3AE, Dark #1FC2CC.
  - Abgeleitete Töne werden in `AccentScale` berechnet, nie hart codiert:
    - light = Mischung Richtung Weiß 0,32
    - deep = Mischung Richtung Schwarz 0,4 (Light) / 0,5 (Dark)
    - deeper = Mischung Richtung Schwarz 0,6
- **Schriften:** Outfit (Titel) und DM Sans (Text), beide als Variable Fonts. Einrichtung siehe `MyListUI/README.md`.
- **Dock:** in Light **und** Dark dunkles Glas. Keine Lichtkante an der Pille.
- **Sheets:**
  - Oberer Radius 34, Griff 40 × 5.
  - Titel in Outfit 22/600.
  - Schließen-Knopf rund, 44 pt.
  - Hintergrund abgedunkelt mit Blur.
- **Popover über dem Dock:**
  - Breite 270, links 20, Unterkante 108 pt über dem Bildschirmrand.
  - Die Zeiger-Raute zeigt auf die Mitte der gewählten Pille.
- **Geometrie:**
  - Inhalt ab 62 pt von oben.
  - Das Dock sitzt 34 pt über der Unterkante.
  - Auf breiteren Geräten wächst nur die Breite.

## 5. Noch nicht gestaltet – NICHT umsetzen

- Live-Gesamtkosten in der Liste
- Avatar „wer hat was“ an Artikeln
- Link „Preisverlauf“ in „Artikel bearbeiten“

Diese drei Punkte kommen später mit eigenem Design. Bis dahin gilt: kein eigenes UI dafür erfinden.

**Übergangslösung für den Preisverlauf:** Der Screen wird gebaut. Bis der Link gestaltet ist, erreicht man ihn über das System-Kontextmenü (langer Druck) auf einen Artikel in „Artikel verwalten“, Eintrag „Preisverlauf“.
