# WatchUI – SwiftUI-Referenz für die Famlist-Watch-App

Stand 26.09.2026 · Quelle: Canvas „My List – Redesign“, Seite **Watch** (`Design/html/Watch*.dc.html`)

## Screens

| Screen | Design-Datei | SwiftUI |
|---|---|---|
| Einkaufsliste | `WatchList.dc.html` | `WatchListScreen` |
| Artikel (Menge per Krone, Abhaken) | `WatchItem.dc.html` | `WatchItemScreen` |
| Hinzufügen (Diktat, „Oft gekauft“) | `WatchAdd.dc.html` | `WatchAddScreen` |
| Alles erledigt | `WatchDone.dc.html` | `WatchDoneScreen` |
| Listen (Wechsel, Favorit) | `WatchLists.dc.html` | `WatchListsScreen` |
| Zifferblatt: Smart Stack + 2 Komplikationen | `WatchFace.dc.html` | `WatchSmartStackView`, `WatchRingComplicationView`, `WatchAddComplicationView` |

## Regeln

- **Pixelgenau:** 1 CSS-px = 1 pt, Artboard 208 × 248 (46 mm). Auf kleineren Uhren wächst/schrumpft nur die Breite.
- **Wahrheitsquelle:** `.dc.html` > dieser Code > Annahme. Der Code wurde **nicht kompiliert** (ohne Xcode geschrieben):
  Compilerfehler minimal beheben, Werte und Optik nicht ändern.
- **Immer dunkel**, Akzent `#1FC2CC`; abgeleitete Töne nur über `WatchTheme` (gleiche Mathematik wie `AccentScale`).
- **Schriften:** Outfit und DM Sans auch im Watch-Target einbinden (`UIAppFonts`).
- **Icons:** Das iOS-Target nutzt Original-SVG-Pfade (`SVGIcon`). Kann das Watch-Target `SVGIcon` teilen, dieses nutzen;
  sonst SF Symbols wie im Referenzcode (Ausnahme nur für watchOS).
- **Uhrzeit** zeichnet watchOS selbst; der Titel links oben ist `navigationTitle` in accentText.
- Eine Type je Datei, `#Preview` für jeden Screen.
