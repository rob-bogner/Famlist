# MyListUI – SwiftUI-Umsetzung des Hybrid-Designs

Pixelgenaue SwiftUI-Umsetzung der 16 Artboards aus dem Canvas „My List – Redesign“:
8 Screens, jeweils in Light und Dark.

| Artboard | SwiftUI |
|---|---|
| Hybrid – Light / Dark | `ListScreen(appearance:)` |
| Produktbild | `ProductImageScreen` |
| Artikel suchen – leer | `SearchEmptyScreen` |
| Artikel suchen – Treffer | `SearchResultsScreen` |
| Neuer Artikel | `NewItemScreen` |
| Abgehakt – Zurück | `ListScreen(state: .checked)` |
| Wisch-Aktionen | `ListScreen(state: .swipe)` |
| Artikel bearbeiten | `EditItemScreen` |

Alle 16 Varianten liegen als Vorschauen in `Previews/AllScreensPreviews.swift`, jeweils auf 390 × 844 pt.

## Dateien

```
Support/CSSRendering.swift   Farben, Verläufe, box-shadow, Rahmen, line-height (CSS → SwiftUI, 1:1)
Support/AppFont.swift        Outfit + DM Sans als Variable Fonts mit exakten Achsen
Support/SVGIcons.swift       Alle Icons als Original-Vektorpfade + SVG-Pfadparser
Theme/Theme.swift            Sämtliche Farb-/Schattenwerte (Liste + Sheets), Akzent-Mathematik
Components/SheetComponents.swift  Sheet-Fläche, Kopf, Buttons, Felder, Stepper, Chips
Screens/ListScreen.swift     Liste inkl. Zustände normal / abgehakt / wischen
Screens/ProductImageScreen.swift
Screens/SearchScreen.swift   leer + Treffer
Screens/ItemFormScreens.swift  Neuer Artikel + Bearbeiten
Previews/AllScreensPreviews.swift
```

Mindestversion: **iOS 17**, weil `UnevenRoundedRectangle`, `Text.foregroundStyle` und `#Preview` mit Traits verwendet werden.

## Einrichtung (Pflicht)

1. **Schriften laden.** Beide Schriften gibt es kostenlos bei Google Fonts (Lizenz OFL). Du brauchst jeweils die **Variable-Font-Datei**:
   - `Outfit[wght].ttf`
   - `DMSans[opsz,wght].ttf` (die Variante mit Achse für optische Größe)
2. Beide Dateien zum App-Target hinzufügen und in der `Info.plist` unter `UIAppFonts` (Fonts provided by application) eintragen.
3. **Namen prüfen.** Einmal `print(UIFont.familyNames.sorted())` ausführen. Die Familien müssen exakt **„Outfit“** und **„DM Sans“** heißen. Weicht ein Name ab, `AppFont.Family` anpassen. Sonst fällt iOS still auf die Systemschrift zurück.

## Referenz-Geometrie

- **Bildschirmgröße:** Das Design ist auf **390 × 844 pt** angelegt. 1 CSS-px entspricht 1 pt.
- **Oben:** Der Inhalt beginnt **62 pt** unter der Bildschirmoberkante. Das entspricht dem oberen Safe-Area-Abstand des iPhone 17 Pro.
- **Unten:** Das Dock sitzt **34 pt** über der Unterkante, also über dem Home-Indikator. Beide Abstände sind absolut, die Safe Area wird ignoriert.
- **Andere Breiten:** Waagerecht ist alles flexibel, wie Flexbox im Design. Auf breiteren Geräten, etwa dem 17 Pro mit 402 pt, werden Karten und Felder breiter. Alle Abstände bleiben gleich.
- **Sheets:** Sie haben feste Höhen und liegen unten bündig: Produktbild 452, Suchen und Neuer Artikel 790, Bearbeiten 726.

## Umrechnungsregeln CSS → SwiftUI

Diese Regeln sind überall umgesetzt und sollten bei Änderungen beibehalten werden.

| CSS | SwiftUI |
|---|---|
| `box-shadow` blur B | Gauß-Radius **B / 2** |
| `box-shadow` spread | Form um den spread-Wert vergrößern oder verkleinern (`inset(by: -spread)`) |
| `box-shadow` außen | wird unter der Box ausgestanzt, genau wie in CSS (`CSSBox`) |
| `box-shadow: inset …` | wird nur innerhalb des Rahmens gezeichnet (Padding-Box) |
| mehrere Schatten | der zuerst genannte liegt oben |
| `filter: blur(X)` | `.blur(radius: X)` |
| `text-shadow` / `drop-shadow` blur B | `.shadow(radius: B / 2)` |
| `border` bei `box-sizing: border-box` | Rahmen liegt innerhalb des Frames, Inhalt ist um Rahmen + Padding eingerückt |
| `border` bei `div` ohne box-sizing (content-box) | Außenmaß = Inhalt + Padding + Rahmen, z. B. Icon-Kachel 48 + 2 = **50** |
| `border-radius` | immer `style: .circular` (CSS-Ecken sind Kreisbögen, **nicht** `.continuous`) |
| `linear-gradient(<winkel>deg)` | `CSSLinearGradient`, exakte CSS-Geometrie für jeden Winkel und jedes Seitenverhältnis |
| `radial-gradient(circle at x% y%)` | `CSSRadialGradient(.circleFarthestCorner)` |
| `radial-gradient(closest-side)` | `CSSRadialGradient(.ellipseClosestSide)` |
| transparente Verlaufsstopps | gleiche RGB-Werte mit α = 0, entspricht der CSS-Interpolation |
| `letter-spacing: Xem` | `.tracking(X × Schriftgröße)` |
| `line-height` | `.cssLineHeight(_:font:)` |
| `font-optical-sizing: auto` (DM Sans) | Achse opsz = Schriftgröße, begrenzt auf 9…40 |

## Screen-Spezifikation (vertikaler Rhythmus in pt)

### Liste – `ListScreen`

| Abstand | Element |
|---|---|
| 62 | Top-Bar: „Aktuelle Liste“ 13/500, darunter 2, dann „My List“ Outfit 30/700 mit Chevron 18; rechts zwei 44er-Kreise mit 10 Abstand |
| 18 | Suchfeld, Höhe 52, Radius 26 |
| 18 | Fortschritts-Karte, Padding 18, Radius 28, Inhalt 16 auseinander: Icon-Reihe → Balken 10 → Chips |
| 18 | Tabs „Alle · Offen · Erledigt“ (26 Abstand, Text 10 oben / 12 unten), Unterstrich 3 pt, Trennlinie 1 |
| 16 | Sektions-Kopf |
| 12 | Artikel-Karte 94 hoch, Padding 14, Radius 24 |

- **Dock:** Pille 68 hoch, links bündig, dazu der FAB mit 68 pt Durchmesser und 12 pt Abstand. Aktive „Liste“-Pille 52 hoch, Nav-Icons 48er Trefferfläche.
- **Zustand `.checked`:** Karte um −86 verschoben, „Zurück“-Knopf 56 in einer 76 breiten Spalte.
- **Zustand `.swipe`:** Karte um −256 verschoben, drei Aktionen 64 × 52 mit Radius 20, Spalten je 76 breit, 8 Abstand.

### Sheets (gemeinsam)

- **Sheet:** oben Radius 34, Innenabstand oben 10 und seitlich 20. Oben der Griff 40 × 5, dann 12, dann die Titelzeile: Outfit 22/600 mit Schließen-Kreis 44.
- **Hintergrund:** Die Liste liegt dahinter, mit 3 weichgezeichnet und darüber abgedunkelt (Light `rgba(8,24,27,.42)`, Dark `rgba(0,0,0,.6)`).
- **Primär-Button:** 56 hoch als Pille, unten 34 und seitlich 20 Abstand.

### Produktbild

Titelzeile → 22 → Bild 220 × 220, Radius 40, Icon 64 → 22 → Name Outfit 26/600 → 8 → Chip mit Padding 5 / 12.

### Artikel suchen – leer

- **Kopf:** Titelzeile → 16 → Suchfeld 54, fokussiert.
- **Leerzustand:** Bereich von y 150 bis 406 im Sheet, darin die Kachel 72 → 14 → Text 15/500 mit Zeilenhöhe 21 und maximal 240 breit.
- **Button:** 14 über der Tastatur.

### Artikel suchen – Treffer

- **Liste:** Suchfeld mit Löschen-Knopf 40 → 20 → „5 Treffer“ 13/600 in Großbuchstaben → 10 → Karten mit 10 Abstand. Jede Karte hat Padding 10, Rahmen 1, Radius 22, Bild 52, Plus-Knopf 44.
- **Fußleiste:** Padding 18 / 20 / 34, Verlauf zur Sheet-Farbe bei 30 %.

### Neuer Artikel

Titelzeile → 18 → [Foto 104 · 14 · Name-Feld 52, fokussiert] → 20 → Menge [Stepper 148 × 52 · 10 · Einheit] → 20 → Kategorie-Chips 42.

### Artikel bearbeiten

Titelzeile → 16 → [Foto 104 · 14 · Name 48 / 8 / Marke 48] → 10 → Beschreibung 48 → 16 → Kategorie → 16 → Menge → 16 → Preis 148 × 52.

## Grenzen der Plattform

Diese Punkte lassen sich mit iOS-Mitteln nicht 1:1 aus dem Browser übertragen. Wo es geht, ist der Unterschied unter einem Pixel oder im statischen Zustand gar nicht sichtbar.

1. **Gestrichelter Rahmen der Foto-Kachel:** Das Strichmuster von Browsern ist nicht standardisiert. Umgesetzt ist 4,5 / 4,5 pt bei 1,5 pt Stärke. Weicht es sichtbar ab, `dash:` in `PhotoAddTile` anpassen.
2. **Oberkante des Dark-Sheets:** CSS lässt `border-top` in den Ecken bis auf 0 auslaufen. Das ist hier über einen Verlauf nachgebildet (`TopBorderHairline`).
3. **Weichzeichner hinter dem Dock (`backdrop-filter`):** Im Design liegt nichts hinter dem Dock, darum ist er standardmäßig aus. Mit `ListScreen(liveDockBlur: true)` wird zusätzlich `.ultraThinMaterial` hinterlegt. Das verändert den Farbton leicht.
4. **Textcursor und Tastatur:** Beide zeichnet iOS selbst. `SearchEmptyScreen` zeigt für den Abgleich mit dem Design einen statischen Cursor und eine Tastaturfläche als Platzhalter. In der App `showsDesignCursor: false` und `showsKeyboardPlaceholder: false` setzen. Dann zeichnet iOS den Cursor in Akzentfarbe (über `.tint`). Den Button 14 pt über der Tastatur verankern, etwa per `.safeAreaInset(edge: .bottom)`.
5. **Sheets:** Bewusst eigene Ebenen statt `.sheet()`. Systemsheets haben ab iOS 26 eigene Radien, Einzüge und Glasflächen.
6. **Schriftskalierung:** Dynamic Type ist für pixelgenaue Treue ausgeschaltet (feste Größen). Soll Barrierefreiheit per Schriftgröße unterstützt werden, `AppFont` auf `UIFontMetrics` umstellen. Das Layout weicht dann bei größeren Schriftstufen ab.
7. **Kantenglättung:** Browser und Core Text glätten Schrift und Kanten minimal unterschiedlich. Das liegt unter einem Pixel.

## Nicht kompiliert

Der Code ist ohne Xcode entstanden. SwiftUI lässt sich in dieser Umgebung nicht kompilieren. Bitte zuerst in Xcode bauen und die 16 Vorschauen gegen die Artboards legen.
