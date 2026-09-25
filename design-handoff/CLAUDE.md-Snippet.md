## Design (Redesign „Hybrid“)

- **Wahrheitsquelle für UI:** `design-handoff/`. Reihenfolge: `Design/html/*.dc.html`, dann `MyListUI/`, dann `Design/png/`.
- **UI pixelgenau:** 1 CSS-px = 1 pt, Artboard 390 × 844. Werte nie runden oder „verschönern“.
- **Referenz-Views übernehmen:** Die Views aus `design-handoff/MyListUI` werden übernommen, nicht neu gebaut. Ersetzt werden nur Beispieldaten und Callbacks.
- **Icons:** nur die Original-SVG-Pfade über `SVGIcon`, keine SF Symbols.
- **Schriften:** Outfit (Titel) und DM Sans (Text) über `AppFont`.
- **Farben:** Akzenttöne kommen immer aus `AccentScale` (Light #0FA3AE, Dark #1FC2CC).
- **Dock:** In Light und Dark dunkles Glas. Genau ein Button ist gewählt und zeigt Highlight und Beschriftung; Ruhezustand ist „Alle abhaken“.
- **Listen-Aktionen:** Umbenennen, Duplizieren, Teilen, Favorit und Löschen gibt es nur in den Listen-Optionen (langer Druck in „Meine Listen“).
- **Profil:** nur über Einstellungen erreichbar.
- **Neues UI:** Kein neues UI ohne Design. Offene Punkte stehen in `design-handoff/SPEC.md` §5.
- **Previews:** Jeder Screen hat eine `#Preview` in Light und Dark.
