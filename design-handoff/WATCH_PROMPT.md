# One-Shot-Prompt: Famlist Apple-Watch-App

```
Baue die Apple-Watch-App für Famlist (watchOS-Companion zur iOS-App im selben Repo).

## Lies zuerst
1. design-handoff/WatchUI/README.md und den SwiftUI-Referenzcode in design-handoff/WatchUI/
2. design-handoff/Design/html/Watch*.dc.html (Wahrheitsquelle, 208 × 248 pt)
3. claude.md / CLAUDE.md (Projektregeln) und die Architektur der iOS-App: SwiftData + SyncEngine (Offline-First,
   CRDT/HLC), Supabase + Realtime, ListViewModel.

## Oberste Anforderung: Watch und iPhone sind IMMER synchron
- Jede Änderung (abhaken, Menge, hinzufügen, zurücksetzen, Listenwechsel) erscheint auf dem anderen Gerät sofort –
  in beide Richtungen, auch Änderungen anderer Familienmitglieder (Realtime).
- Offline-First auch auf der Uhr: Aktion sofort lokal anzeigen, dann synchronisieren; nichts darf verloren gehen,
  wenn iPhone oder Netz gerade nicht erreichbar sind.
- Konflikte löst dieselbe Logik wie im iPhone (HLC/LWW) – keine zweite Wahrheit erfinden.
- Architektur in Phase 0 entscheiden und begründen. Erwartet wird mindestens:
  - WatchConnectivity: sendMessage bei Erreichbarkeit, transferUserInfo als Warteschlange, applicationContext für den
    aktuellen Listenstand; iPhone bleibt Quelle der Wahrheit und schreibt über die bestehende SyncEngine.
  - Bewerten: eigener Supabase-Zugang der Uhr (geteilter Login über Keychain-Access-Group), damit sie auch ohne
    iPhone synchron bleibt (LTE/WLAN). Wenn ja: gleiche Repositories/SyncEngine als geteiltes Framework/Package statt Kopie.
  - Widgets/Komplikationen über App Group aktualisieren (WidgetCenter.reloadTimelines) bei jeder Änderung.
- Tests: Sync-Szenarien (Uhr offline → online, iPhone ändert während Uhr offline, gleichzeitige Änderung).

## Umfang
- Neues watchOS-Target (watchOS 10+) + Widget-Extension für Smart Stack und 2 Komplikationen (WatchFace.dc.html).
- Screens pixelgenau aus WatchUI übernehmen: Liste, Artikel (Menge per Digital Crown), Hinzufügen (Diktat +
  „Oft gekauft“ aus dem Artikelstamm), Alles erledigt (Zurücksetzen), Listen (Favorit zuerst).
- Abhaken per Tipp auf den Kreis bzw. „Abhaken“; „Alle abhaken“ unten links; Haptik bei Abhaken.
- Deep Links famlist://watch/list und famlist://watch/add aus den Komplikationen.
- Accessibility: VoiceOver-Labels wie aria-labels im HTML, Dynamic Type darf nichts abschneiden.
- Deutsch, UserLog nur in ViewModels, eine Type je Datei, neue Dateien in project.pbxproj, #Preview je Screen.

## Vorgehen
Phase 0: Bestandsaufnahme + design-handoff/WATCH_PLAN.md (Architektur Sync, Targets, Datenfluss, Risiken, offene Fragen).
Zeig mir den Plan und stell nur echte Blocker-Fragen, bevor du baust. Danach Phase für Phase, Build grün nach jeder
Phase, eigener Commit je Phase.
```
