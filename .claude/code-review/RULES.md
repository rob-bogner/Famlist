# Famlist – Review-Regeln

Maßstab für den täglichen Code-Review. Abgeleitet aus den Agenten-Rollen in
`.claude/agents/` und `design-handoff/CLAUDE.md-Snippet.md`. Bei Widerspruch
gelten jene Dateien; diese hier dann korrigieren.

## 1. Architektur

Jeder Verstoß ist ein Befund. Die Priorität richtet sich nach der Folge
(siehe REVIEW_PROMPT.md), nicht nach der Kategorie.

- **Offline-First:** SwiftData ist die Wahrheitsquelle, Supabase nur der Sync-Layer.
- **Datenfluss:** View → ViewModel → Repository → SwiftData → SyncEngine → Supabase.
- **Kein Supabase im UI:** `import Supabase` ist nur erlaubt in `Famlist/App`,
  `Famlist/Core/Networking`, `Famlist/Core/Sync`, `Famlist/Repositories/Implementations`
  und in Tests. Überall sonst ist es ein Befund.
- **Repositories:** Protokoll in `Repositories/Protocols/`, Implementierung in
  `Repositories/Implementations/`. ViewModels hängen nur an Protokollen.
- **Eine Wahrheit:** Remote-Stände kommen nur über Repository oder SyncEngine
  nach SwiftData, nie direkt aus einem ViewModel oder einer View. Keine
  konkurrierenden Observer-Pipelines in ViewModels. Bulk-Mutationen brauchen
  einen Transaction Guard.
- **Sync deterministisch:** Konfliktlösung über HLC/LWW, nie über Wanduhrzeit.

## 2. Concurrency

- UI-State nur auf `@MainActor`; ViewModels und Stores sind `@MainActor`.
- Kein `Task { }` ohne Besitzer, wenn er länger lebt als die View: Handle
  speichern und abbrechen. Kurze UI-Aktionen (ein Tap, ein Speichern) sind ok.
- Kein `unowned` ohne garantierte Lebensdauer; im Zweifel `weak`.
- Keine blockierenden Aufrufe auf dem Main Thread, kein Warten der UI auf Netzwerk.
- Typen über Actor-Grenzen sind `Sendable`.

## 3. SwiftUI und State

- Neuer Code nutzt `@Observable`/`@Bindable`. `ObservableObject` ist Bestand:
  nur melden, wenn eine geänderte Datei es **neu** einführt.
- Views bleiben klein: Unteransichten auslagern statt `body` über ~80 Zeilen.
- Keine teure Arbeit in `body` (Sortieren, Filtern, Formatter anlegen). Formatter
  und Decoder werden wiederverwendet, nicht pro Aufruf oder in Schleifen erzeugt.
- Jeder Screen hat `#Preview` in Light und Dark.

## 4. Design-Regeln (aus dem Handoff)

- Wahrheitsquelle für UI ist `design-handoff/`. Maße pixelgenau, nie runden.
- Icons nur über `SVGIcon`, keine SF Symbols (`systemName:` ist ein Befund).
- Schriften nur über `AppFont`, Akzentfarben nur aus `AccentScale`.
- Alle Buttons im Glas-Stil der Designsprache; keine Apple-Systemdialoge
  (`.alert`, `.confirmationDialog`, `.actionSheet` sind ein Befund).
- Maße aus dem Design stehen als Zahl im Code. Das sind **keine** Magic Numbers.

## 5. Code-Hygiene

- Ein Typ pro Datei, Dateiname = Typname. Ausnahme: kleine private Hilfstypen.
- Datei-Kopfkommentar im Projektformat (File Overview / Notes / Last Change) bleibt.
- Kein `print(` im Produktivcode; Logging über `logVoid`/`logResult` und `UserLog`.
- Kein `try!`, `as!`, kein Force-Unwrap außerhalb von Tests und Previews.
- Klassen sind `final`, solange nicht bewusst vererbt wird.
- Kein auskommentierter Code, keine TODOs ohne Ticket.
- Schwellen: Datei 500 Zeilen, Typ 300, Funktion 60, zyklomatische
  Komplexität 12. Das sind die Warn-Schwellen in `.swiftlint.yml`; ab dort ist
  es ein Befund.

## 6. Toter und doppelter Code

- **Tot** ist ein Symbol erst, wenn die Gegenprüfung mit `grep` keine Nutzung
  zeigt – auch nicht über Strings, Protokolle, Makros, Intents oder Widgets.
- Symbole, die nur Tests nutzen, getrennt melden („nur von Tests genutzt“).
- Eine View, die nur ihre eigene `#Preview` aufruft, ist tot. Bausteine, die
  nur von toten Views genutzt werden, sind es auch.
- Gesucht wird in `Famlist`, `FamlistWatch`, `FamlistWatchWidgets`,
  `FamlistWatchTests`, `FamlistUITests` – nicht in `design-handoff/` und `scripts/`.
- **Doppelt** zählt ab ~15 gleichen Zeilen oder wenn zwei Typen dasselbe tun.
  Ähnliche Design-Views aus dem Handoff sind oft gewollt: erst prüfen, ob eine
  die andere abgelöst hat (dann ist die alte toter Code).

## 7. Bewusste Ausnahmen (nicht melden)

- snake_case-Namen in DTOs, die Supabase-Spalten spiegeln.
- Zeilenweise Kommentare im Stil „Notes for Beginners“.
- `OperationQueue` als eigener Typname (Kollision mit Foundation ist bekannt).
- `ConnectivityMonitor` und `ImageCache` als Singletons.
- Übernommene Referenz-Views aus `design-handoff/MyListUI`. Ihre Kopien liegen in
  `Famlist/Shared/Components/Hybrid/Design/` (Präfix `Design…`): nicht „aufräumen“,
  Ähnlichkeit zu Bestands-Views dort ist kein Duplikat-Befund.
- `print(` in `Core/Utils/Logger.swift` und `UserLogger.swift` (das ist das Logging selbst).
- Code hinter `#if DEBUG` bzw. `targetEnvironment(simulator)`: Design- und
  Hygiene-Regeln gelten dort nicht.
- Alles, was in `ACCEPTED.md` steht.
