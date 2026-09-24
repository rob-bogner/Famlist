# Design-Übergabe an Claude Code (VS Code)

## Inhalt

- `SPEC.md`: Screens, Workflows, Designregeln und was bewusst noch nicht umgesetzt wird
- `PROMPT.md`: One-Shot-Prompt für Claude Code
- `MyListUI/`: SwiftUI-Referenzcode aller 33 Screens in Hell und Dunkel, dazu Dock, Overlays und Previews
- `Design/html/`: Original-Design als HTML/CSS (Wahrheitsquelle)
- `Design/png/`: 66 Referenzbilder @2x, dazu Zielstruktur und Dock-Zustände
- `CLAUDE.md-Snippet.md`: Regeln, die Claude Code dauerhaft kennen soll

## So gehst du vor

1. **Branch anlegen.** Im App-Repo einen eigenen Branch erstellen, z. B. `redesign-hybrid`.
2. **Ordner kopieren.** Diesen Ordner als `design-handoff/` ins Wurzelverzeichnis des Repos kopieren.
3. **CLAUDE.md ergänzen.** Den Inhalt von `CLAUDE.md-Snippet.md` in die `CLAUDE.md` des Repos einfügen. Gibt es keine, eine neue anlegen.
4. **Claude Code starten.** In VS Code das Claude-Code-Panel öffnen und in den **Plan-Modus** wechseln (Shift+Tab).
5. **Prompt einfügen.** Den Block aus `PROMPT.md` einfügen. Claude Code liest zuerst alles und legt `design-handoff/PLAN.md` an.
6. **Plan prüfen.** Lies den Plan und beantworte offene Fragen, vor allem zum Backend für Preise und Einladungen. Dann den Plan-Modus verlassen und Phase für Phase freigeben.
7. **Nach jeder Phase prüfen.** Build in Xcode, Previews gegen `Design/png` vergleichen, dann committen.

Tipp: Pro Phase eine neue Claude-Code-Sitzung mit „Weiter mit Phase X laut design-handoff/PLAN.md“ hält den Kontext klein und die Qualität hoch.
