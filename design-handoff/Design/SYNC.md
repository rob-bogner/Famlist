# Design-Sync: Canvas ↔ design-handoff

Quelle der Wahrheit ist das Claude-Design-Canvas „Famlist“ (claude.ai/code/artifact/1c806407-1994-47b0-a66b-52dc35e8d961).
`Design/html/` ist eine 1:1-Kopie der Canvas-Boards (`project/*.dc.html` + `canvas.json`).

- Jede Änderung im Canvas wird im selben Schritt hierher übernommen – nie nur an einer Stelle ändern.
- Bilder aus dem Canvas liegen lokal unter `html/assets/` (Obst: `assets/fruit/fruit.<id>.svg`, Splash: `assets/img/`);
  die Boards verweisen darauf statt auf `/_blob/…`.
- Boards, die im Canvas nicht mehr existieren, werden hier gelöscht.
- `Design/png/` wird bei jedem Abgleich neu gerendert (@2x, Board-Größe laut `canvas.json`).
- SPEC.md §2 (Screen-Übersicht) wird beim Abgleich mit aktualisiert.

Letzter Abgleich: 27.09.2026 · Canvas-Version 1790523259-7b17 · 162 Boards/Dateien + 39 Bilder · 161 PNG
