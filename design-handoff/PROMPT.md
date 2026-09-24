# One-Shot-Prompt für Claude Code

Den Block unten vollständig in Claude Code einfügen. Vorher den Ordner `design-handoff/` ins Wurzelverzeichnis des App-Repos kopieren.

---

```
Du setzt das neue Design „Hybrid“ der iOS-App Famlist (Einkaufsliste, SwiftUI) pixelgenau um und ergänzt die fehlenden Funktionen. Alles Nötige liegt in ./design-handoff/.

## Lies zuerst, vollständig
1. design-handoff/SPEC.md: Screens, Workflows, Designregeln, Abgrenzung (Abschnitt 5 NICHT umsetzen)
2. design-handoff/MyListUI/README.md: CSS→SwiftUI-Regeln, Schrift-Einrichtung, Geometrie
3. design-handoff/MyListUI/: SwiftUI-Referenzcode ALLER Screens (Views mit Beispieldaten und Callbacks)
4. design-handoff/Design/png/StructureMap.png und DockStates.png ansehen

## Oberste Regel: pixelgenau
- Die Views aus design-handoff/MyListUI sind die Vorlage. Übernimm sie 1:1 ins App-Target: Layout, Werte, Farben, Schatten, Radien, Schriften und Icons (Original-SVG-Pfade, keine SF Symbols). Ersetze nur die Beispieldaten und die leeren Callbacks durch echte Daten und Aktionen.
- Nichts „verschönern“, vereinfachen oder durch Systemkomponenten ersetzen. Wenn eine Systemkomponente Pflicht ist (Kamera, Share Sheet, Sign in with Apple, Dokumentscanner), liegt das Design-UI darüber bzw. drumherum wie im Referenzcode.
- Bei Widersprüchen gilt: Design/html/*.dc.html > MyListUI > deine Annahme. Die Referenzbilder in Design/png (@2x) dienen zum Sichtvergleich.
- Der Referenzcode wurde nicht kompiliert (erstellt ohne Xcode). Behebe Compilerfehler minimal, ohne Optik oder Werte zu ändern.

## Vorgehen
Phase 0 – Bestandsaufnahme (noch nichts ändern):
- Analysiere das bestehende Projekt: Architektur, Navigation, Datenmodell, Persistenz und Sync-Backend (herausfinden, nicht annehmen), Auth, Teilen/Einladungen, Deployment Target.
- Lege design-handoff/PLAN.md an:
  - Mapping „bestehender Screen/Code → neuer Screen aus SPEC.md“
  - Liste der fehlenden Funktionen mit nötigen Datenmodell- und Backend-Änderungen
  - Reihenfolge der Phasen
  - Risiken und offene Fragen
- Stell mir nur echte Blocker-Fragen (z. B. welches Backend für Preisdaten), sonst triff sinnvolle Entscheidungen und dokumentiere sie in PLAN.md.

Phase 1 – Fundament:
- Übernimm Support/, Theme/ und Components/ aus MyListUI.
- Binde die Fonts Outfit und DM Sans (Variable) ein und prüfe die Familiennamen.
- Deployment Target mindestens iOS 17.
- Der Build muss grün sein.

Phase 2 – Liste und Dock (Kern):
- ListScreen mit echten Daten: Tabs, Fortschritt, Kategorien-Sektionen in Ladenweg-Reihenfolge, Abhaken mit „Zurück“, Wisch-Aktionen, Leer-Zustand.
- „Ansicht wechseln“ ist entfernt. Im Hero gibt es keine „offen/erledigt“-Chips und kein Label „Aktuelle Liste“.
- DockView mit der Auswahl-Logik aus SPEC §3.4:
  - Die Pille wandert animiert zum angetippten Button.
  - Sortieren: Popover, Einstellung pro Liste gespeichert.
  - Kopieren: Popover, dann UIPasteboard im Textformat aus der SPEC, dazu Zustand „Kopiert“ und Toast.
  - Löschen: Popover, dann Toast mit Rückgängig (5 s), kein Bestätigungsdialog.
  - Alle abhaken / Zurücksetzen.
  - Leere Liste: gedimmt.
- Kontext-Menü ☰ mit genau den 4 Einträgen aus der SPEC.
- Der Plus-Button öffnet direkt „Neuer Artikel“.

Phase 3 – Artikel:
- Suchen (leer/Treffer, „Neu anlegen“), Neuer Artikel, Artikel bearbeiten (inkl. Preis), Produktbild.
- Artikel verwalten: Artikelstamm mit Suche, Filterchips, bearbeiten, löschen.
- Barcode-Scanner: VisionKit DataScannerViewController für EAN/UPC. Das Design-UI liegt darüber. Bekannte Codes treffen einen Artikel im Artikelstamm. Unbekannte Codes öffnen „Neuer Artikel“ vorbefüllt; für den Namen optional Open Food Facts abfragen (in PLAN.md entscheiden). Kamera-Berechtigung und Texte in Info.plist.

Phase 4 – Listen, Teilen, Konto:
- Meine Listen, Neue Liste (Favorit = öffnet beim Start).
- Listen-Optionen per langem Druck: Umbenennen, Duplizieren, Favorit, Mitglieder & Teilen, Löschen bzw. Verlassen.
- Mitglieder & Teilen: Einladungslink per ShareLink, Link kopieren, öffentliche ID.
- Einstellungen: Profilkarte, Erscheinungsbild System/Hell/Dunkel app-weit (preferredColorScheme), Benachrichtigungs-Schalter, Abmelden.
- Profil bearbeiten.
- Konto löschen: löscht Daten im Backend wirklich; App-Store-Pflicht.

Phase 5 – Einstieg:
- Anmelden: E-Mail und Sign in with Apple.
- Profil anlegen: Benutzername mit Live-Verfügbarkeitsprüfung.
- Einladung annehmen über Universal Link / Deep Link, inklusive Kaltstart ohne Konto.
- Leere Liste für neue Nutzer.

Phase 6 – Kategorien:
- Kategorien verwalten: Reihenfolge = Ladenweg, umsortieren per Ziehen, neue Kategorie.
- Kategorie bearbeiten: Name, Icon, Löschen. Artikel wandern nach „Sonstiges“, das nicht löschbar ist.
- Die Reihenfolge steuert die Sortierung „Nach Kategorie“.

Phase 7 – Kassenzettel und Preise:
- Kassenzettel fotografieren: mehrteilige Aufnahme.
- OCR mit Vision (VNRecognizeTextRequest, Sprache de-DE). Positionen und Preise parsen; Laden und Datum erkennen.
- Zuordnung zu Artikeln (unscharfer Namensabgleich), Status Zugeordnet / Zuordnung prüfen / Neuer Artikel?; der Nutzer kann jede Zuordnung korrigieren.
- „Preise speichern“ legt einen Preispunkt an (Artikel, Laden, Datum, Preis).
- Einkauf erledigt mit Summe.
- Preisverlauf: Tiefster, Schnitt, Höchster Preis, Monatsdiagramm, „Nach Laden“ mit Markierung GÜNSTIGSTER.
- Einstieg zum Preisverlauf vorerst wie in SPEC §5 (Übergangslösung).
- Die OCR-Logik bekommt Unit-Tests mit 3–4 Beispiel-Bons als Text.

## Qualität, nach jeder Phase
- Der Build ist grün, bestehende Tests laufen. Für neue Logik (Sortierung, Kopier-Textformat, Löschen und Rückgängig, Bon-Parser, Preis-Statistik) schreibst du Unit-Tests.
- Für jeden neuen Screen gibt es #Preview in Light und Dark mit 390 × 844.
- Pixel-Abgleich: Wenn der iOS-Simulator verfügbar ist, mache Screenshots (iPhone 17 Pro, 402 pt breit; das Design ist 390 breit, nur die Breite wächst) und vergleiche sie mit Design/png. Abweichungen behebst du oder dokumentierst sie in PLAN.md.
- Accessibility: VoiceOver-Labels wie die aria-labels im HTML, Mindest-Tap-Fläche 44 pt, Dynamic Type darf das Layout nicht brechen.
- Strings auf Deutsch, über String Catalog.
- Mach nach jeder Phase einen eigenen Commit mit einer klaren Nachricht und hake die Phase in PLAN.md ab.

## Nicht tun
- Punkte aus SPEC §5 umsetzen oder eigenes UI erfinden.
- Bestehende Nutzerdaten ohne Migration verändern; Datenmodell-Änderungen immer mit Migration.
- Den Ordner design-handoff/ ins App-Target aufnehmen. Er bleibt Referenz; übernommene Dateien werden ins Projekt kopiert.

Beginne mit Phase 0 und zeig mir PLAN.md, bevor du Phase 1 startest.
```
