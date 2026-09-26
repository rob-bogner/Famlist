# WATCH_PLAN – Famlist für die Apple Watch

Stand 26.09.2026 · Phase 0 (Bestandsaufnahme und Plan) · Auftrag: `design-handoff/WATCH_PROMPT.md`

Status: **Phasen 1–7 gebaut (26.09.2026); offen: Gerätetest und Abnahme durch Robert.** Phase 3: Migrationen 022 und 023 sowie Edge Function `watch-session` sind live (Freigabe Robert, 17:38).

---

## 1. Bestandsaufnahme (geprüft am 26.09.2026)

| Bereich | Befund | Beleg |
|---|---|---|
| Xcode-Projekt | Klassisches `project.pbxproj` (objectVersion 56) ohne synchronisierte Ordner. Es gibt drei Targets: `Famlist`, `FamlistTests`, `FamlistUITests`. | `grep productType project.pbxproj` |
| Werkzeug für neue Targets | Das Ruby-Gem `xcodeproj` 1.23.0 ist installiert. Damit lassen sich Targets sauber per Skript anlegen, statt die pbxproj von Hand zu bearbeiten. | `gem list xcodeproj` |
| iOS-App | Die App hat die Bundle-ID `com.roxo.famlist` und das Team `YHSZ8G8RWJ`. Sie nutzt Swift 6 mit strikter Nebenläufigkeitsprüfung, iOS 17.0 als Minimum und das URL-Schema `famlist`. | pbxproj, `Famlist/Info.plist` |
| Entitlements | Die App hat nur „Sign in with Apple“. Es gibt keine App Group, keine Keychain-Gruppe und kein Push (APNs). | `Famlist/Famlist.entitlements` |
| SDK | Installiert sind watchOS 26.5 SDK und Simulator. Der Simulator „Apple Watch Series 11 (46mm)“ hat 208 × 248 pt und passt damit genau zum Artboard. | `xcodebuild -showsdks`, `simctl list` |
| Roberts Geräte | „Apple Watch von Rob“ (Apple Watch Ultra, Watch6,18) ist mit dem iPhone 16 Pro Max gekoppelt und verfügbar. | `devicectl list devices` |
| supabase-swift | Version 2.31.2 unterstützt watchOS ab 6. `KeychainLocalStorage` akzeptiert eine `accessGroup`. | `Package.swift`, `Package.resolved` |
| Artikel-Schreibweg | Die `SyncEngine` (@MainActor) schreibt jede Änderung mit neuer HLC in SwiftData und reiht sie ein. Danach sendet sie gebündelt an die RPC `upsert_items_lww`. Die Konfliktentscheidung trifft der Server nach Last-Writer-Wins; lokal entscheidet `ItemSyncPolicy`. | `SyncEngine.swift`, `SwiftDataItemStore.mergeRemote` |
| HLC | Der `HybridLogicalClockGenerator` speichert Geräte-ID und letzten Stand in UserDefaults. Der Server lehnt HLCs ab, die mehr als 1 Tag in der Zukunft liegen. | `HybridLogicalClock.swift` |
| Artikel-ID | Die ID ist deterministisch aus Liste und Name (UUID v5 über SHA-256). Legen zwei Geräte „Milch“ an, entsteht dieselbe ID und damit kein Duplikat. | `UUID+DeterministicItemID.swift` |
| Realtime | Das iPhone abonniert **nur die aktive Liste** über einen privaten Broadcast-Kanal, und das nur, solange die App läuft. | `SupabaseRealtimeManager`, `ListViewModel+RealtimeSync` |
| Favorit | Der Favorit steht in `profiles.favorite_list_id`. Ohne Favorit gilt die Standardliste (`is_default`). | `AppSessionViewModel+Account.swift` |
| „Zurücksetzen“ | Dafür gibt es `ListViewModel.toggleAllItems()`: Sind alle Artikel abgehakt, hebt die Methode alle Haken auf. | `ListViewModel+BulkActions.swift` |
| Artikelstamm | Die Tabelle `item_catalog` hat `UNIQUE (owner_public_id, name_lower)`, aber **keinen Zähler**. „Oft gekauft“ braucht deshalb Migration 022 (§9). | `ItemCatalogRepository.swift`, live `information_schema` |
| Konten | Alle 5 Konten haben eine E-Mail-Adresse. Der Anmelde-Code für die Uhr (§2) funktioniert deshalb für jedes Konto, auch bei „Sign in with Apple“. | live `auth.users` |
| Edge Functions | Im Projekt laufen bereits `publish-to-room` und `make-server-515802c7`. Eine weitere Function ist also technisch vorgesehen. | MCP `list_edge_functions` |
| Teilbare Dateien | `HybridLogicalClock`, `ItemSyncPolicy`, `UUID+DeterministicItemID`, `CRDTMetadata`, `ItemModel`, `Logger` und `UserLogger` importieren nur Foundation oder CryptoKit. Die SVG-Icons importieren nur SwiftUI. Alle diese Dateien kompilieren voraussichtlich auch für watchOS. | `grep ^import` |

### Plattform-Grenzen (recherchiert, mit Quelle)

1. **Die Uhr kann Supabase Realtime nicht nutzen.** watchOS erlaubt WebSockets (`URLSessionWebSocketTask`) und das Network-Framework nur Audio-Streaming-Apps, VoIP-Apps während eines Anrufs und dem tvOS-Sonderfall. Andere Apps bleiben im Zustand „waiting“ mit ENETDOWN hängen. Auch `NWPathMonitor` bleibt dauerhaft `.unsatisfied`, deshalb ist der `ConnectivityMonitor` der iOS-App auf der Uhr unbrauchbar. Der Simulator erlaubt das alles, deshalb fällt es dort nicht auf. Normales HTTPS über `URLSession` geht immer.
   Quelle: Apple TN3135 „Low-level networking on watchOS“.
2. **Die Keychain wird nicht zwischen iPhone und Uhr geteilt.** Eine Keychain-Access-Group wirkt nur innerhalb eines Geräts; seit watchOS 2 laufen Uhr-Apps auf der Uhr selbst. Teilen ginge nur über WatchConnectivity oder über die iCloud-Keychain (`kSecAttrSynchronizable`). `KeychainLocalStorage` von supabase-swift setzt dieses Attribut nicht.
   Quellen: Apple Developer Forums Thread 79866 und 20540.
3. **Eine Supabase-Sitzung darf nicht auf zwei Geräten laufen.** Refresh-Tokens sind einmalig gültig; nur innerhalb von 10 Sekunden ist eine zweite Nutzung erlaubt. Später gilt das als Diebstahl, und **die ganze Sitzung wird widerrufen**. Nutzen iPhone und Uhr dieselbe Sitzung, würde irgendwann auch das iPhone abgemeldet. Die Uhr bräuchte deshalb eine **eigene** Sitzung.
   Quelle: supabase.com/docs/guides/auth/sessions.
4. **Wie WatchConnectivity zustellt:**
   - `sendMessage` von der Uhr **weckt die iPhone-App im Hintergrund**. Umgekehrt weckt das iPhone die Uhr-App nicht.
   - `transferUserInfo` stellt garantiert und in der Reihenfolge zu, auch wenn die App angehalten ist. **Im Simulator gibt es diesen Weg nicht**; er lässt sich nur auf echten Geräten testen.
   - `updateApplicationContext` ersetzt jedes Mal den vorigen Stand und kommt an, sobald das Gegenüber erwacht.
   Quelle: Apple-Doku zu WCSession.
5. **Ein Anmelde-Code lässt sich ohne Mail erzeugen.** `auth.admin.generateLink` „generates an email link for a specific action without sending it“. `verifyOTP(tokenHash:type:)` ist in supabase-swift 2.31.2 vorhanden.
   Quellen: supabase.com/docs/reference/swift/auth-admin-generatelink und `Sources/Auth/AuthClient.swift` Zeile 1024.

---

## 2. Architektur (entschieden)

### Roberts Entscheidungen vom 26.09.2026

| Frage | Entscheidung |
|---|---|
| Eigener Supabase-Zugang der Uhr | **Jetzt.** Die Uhr ist ein vollwertiger Sync-Knoten. |
| „Oft gekauft“ | **(a)** Migration 022: Zähler `use_count` und Zeitpunkt `last_used_at` im Artikelstamm. Beide zählen bei jedem Hinzufügen zu einer Liste hoch. |
| Aktive Liste | **Jedes Gerät behält seine aktive Liste.** Alle Listen bleiben auf beiden Geräten jederzeit synchron. |

### Grundsatz: Zwei gleichberechtigte Knoten, ein Server-Schiedsrichter

```text
 Uhr (watchOS)                                   iPhone (iOS)
┌───────────────────────────────┐              ┌────────────────────────────────┐
│ Screens → Watch-ViewModels    │              │ Screens → ListViewModel         │
│ SyncEngine (dieselbe Datei)   │              │ SyncEngine                      │
│ SwiftData (eigener Speicher)  │  WatchConn.  │ SwiftData                       │
│ eigene HLC-Geräte-ID          │ ◀──────────▶ │ WatchBridge (neu)               │
│ eigene Sitzung (Keychain Uhr) │  sofort-Weg  │ Realtime für ALLE Listen (neu)  │
└──────────────┬────────────────┘              └───────────────┬────────────────┘
               │ HTTPS: upsert_items_lww, Delta-Abfrage         │ HTTPS + WebSocket (Realtime)
               ▼                                                ▼
        ┌──────────────────────────────────────────────────────────────┐
        │ Supabase: items (LWW-Wächter), item_catalog (+Zähler), Auth  │
        └──────────────────────────────────────────────────────────────┘
```

- **Jedes Gerät sendet seine eigenen Änderungen selbst an Supabase.** Beide nutzen dafür denselben Code: die `SyncEngine` mit der dauerhaften Warteschlange in SwiftData, dieselbe HLC-Datei und dieselbe `ItemSyncPolicy`. Jedes Gerät hat eine eigene HLC-Geräte-ID. Den Konflikt entscheidet der Server mit `upsert_items_lww` (LWW), wie heute zwischen zwei iPhones. Damit entsteht keine zweite Wahrheit.
- **Die Uhr hat eine eigene Sitzung.** Braucht die Uhr eine Anmeldung, bittet sie das iPhone per `sendMessage` darum; das weckt die iPhone-App im Hintergrund. Das angemeldete iPhone ruft die neue Edge Function `watch-session` auf. Diese prüft die Anmeldung, erzeugt mit dem Service-Schlüssel per `generateLink` (Typ magiclink) einen einmaligen Code und verschickt keine Mail. Das iPhone antwortet der Uhr mit dem Code. Die Uhr löst ihn mit `verifyOTP(tokenHash:type: .magiclink)` ein und hat danach eine **eigene** Sitzung in ihrer eigenen Keychain. Die Sitzung des iPhones bleibt unberührt (§1, Grenze 3).
- **Der Code läuft nie über `applicationContext`.** Der würde ihn liegen lassen. Er läuft nur als Antwort auf `sendMessage`.

### Wie Änderungen auf das andere Gerät kommen

| Weg | Wann | Verzögerung |
|---|---|---|
| **Sofort-Weg über WatchConnectivity** | Nach jeder Änderung schickt das Gerät die geänderten Zeilen (ohne Fotos) per `sendMessage` an das andere Gerät, sofern es erreichbar ist. Das Gegenüber übernimmt sie nur über `mergeRemote` (HLC-Vergleich) und sendet sie **nicht** erneut an den Server. | sofort |
| **Realtime auf dem iPhone, jetzt für alle Listen** | Das iPhone abonniert künftig die Kanäle **aller** Listen, nicht nur der aktiven. Ereignisse fremder Listen landen über dieselbe Merge-Logik in SwiftData, und das iPhone leitet sie über den Sofort-Weg an die Uhr weiter. | ca. 1 s, solange die iPhone-App läuft |
| **Eigene Abfrage der Uhr** | Beim Öffnen der Uhr-App und danach alle 10 s, solange sie sichtbar ist: eine Delta-Abfrage für alle Listen in **einem** Aufruf (`fetchItemsSince(listIds:since:)`, neu). | ≤ 10 s, auch ohne iPhone |
| **Hintergrund der Uhr** | `WKApplicationRefreshBackgroundTask`. Das System teilt die Zahl der Läufe zu, deshalb ist kein fester Takt zugesagt. Genutzt wird das für Komplikationen und Smart Stack. | Minuten |
| **Hinweis vom iPhone** | Das iPhone setzt nach Änderungen `updateApplicationContext` mit einem Hinweis „Listen X, Y geändert“. Beim nächsten Aufwachen fragt die Uhr diese Listen zuerst ab. | beim Aufwachen |

**Was „jederzeit realtime synchron“ auf der Uhr technisch heißt** (Grenze §1.1, nicht umgehbar):
- Bei sichtbarer Uhr-App und laufender iPhone-App kommen Änderungen sofort, auch Änderungen anderer Familienmitglieder in jeder Liste.
- Ohne iPhone kommen sie nach höchstens 10 s.
- Im Hintergrund der Uhr kommen sie, wenn watchOS die App weckt.

**Offline und „nichts geht verloren“:**
- Jede Aktion auf der Uhr steht sofort in ihrer SwiftData und in ihrer Warteschlange. Beides übersteht auch einen Neustart der Uhr. Gesendet wird, sobald eine Verbindung besteht. Die Uhr geht dabei selbst ins Netz; ist das iPhone in der Nähe, laufen die Anfragen laut Apple über das iPhone.
- Ohne gültige Sitzung (noch nie gekoppelt oder widerrufen) bleibt die Warteschlange einfach liegen. Dafür liefert `isOnline` auf der Uhr „Sitzung vorhanden“. Der `NWPathMonitor` ist dort unbrauchbar (§1.1). Echte Netzfehler erkennt der vorhandene `SyncErrorClassifier` an den `URLError`s und wartet dann ab.

**Warum `transferUserInfo` nicht mehr als Änderungs-Warteschlange dient:**
- Der Auftrag nannte `transferUserInfo` als Warteschlange. Mit eigenem Zugang ist die Warteschlange der `SyncEngine` stärker: Sie liegt dauerhaft in SwiftData, der **Server** quittiert jede Änderung, und sie funktioniert auch ohne iPhone.
- `transferUserInfo` bekommt deshalb die Nachrichten, die garantiert ankommen müssen: **Abmelden** und **Kontowechsel** auf dem iPhone. Die Uhr meldet sich dann ebenfalls ab und leert ihren Speicher, damit nichts ins nächste Konto gelangt (wie `resetForSignOut` auf dem iPhone).

### Aktive Liste
- Jedes Gerät merkt sich seine aktive Liste selbst (Uhr: UserDefaults). Beim ersten Start zeigt die Uhr den Favoriten, sonst die Standardliste.
- Alle Listen samt Artikeln liegen auf beiden Geräten und bleiben nach den Wegen oben synchron. Beim Listenwechsel auf der Uhr muss daher nichts nachgeladen werden.

### Code-Teilung: Target-Mitgliedschaft statt Framework
- Der Auftrag verlangt „geteiltes Framework oder Package statt Kopie“. Ich nehme **dieselben Quelldateien in beiden Targets**; das ist ebenfalls keine Kopie.
- **Grund:** Ein Framework oder Package verlangt `public` an jedem Typ, den die App benutzt. Das wären grob 40 Dateien, und die gesamte iOS-App müsste umgebaut werden, nur damit die Uhr kompiliert.
- Geteilt werden:
  - Modelle (`ItemEntity`, `ListEntity`, `SyncOperation` samt Mapping)
  - Sync-Kern (`SyncEngine`, Warteschlange, HLC, `ItemSyncPolicy`, Backoff, Fehlerklassen)
  - `SwiftDataItemStore`, `PersistenceController`
  - der Supabase-Client und die Repositories für Artikel, Listen, Profil und Artikelstamm
  - Logger, `UserLogger` und SVG-Icons
- Wo eine Datei UIKit oder WebSocket-Realtime zwingend braucht, trenne ich genau diesen Teil in eine eigene Datei ab. Die Uhr ruft `observeItems` (Realtime) nie auf.

---

## 3. Targets und Signierung

| Target | Typ | Bundle-ID | Minimum | Inhalt |
|---|---|---|---|---|
| `FamlistWatch` | watchOS-App (ein Target) | `com.roxo.famlist.watchkitapp` | watchOS 10.0 | Screens, ViewModels, geteilter Kern, WatchConnectivity, Supabase |
| `FamlistWatchWidgets` | WidgetKit-Erweiterung (watchOS) | `com.roxo.famlist.watchkitapp.widgets` | watchOS 10.0 | Smart Stack und 2 Komplikationen |
| `FamlistWatchTests` | Unit-Tests (watchOS) | `com.roxo.famlist.watchkitapp.tests` | watchOS 10.0 | Uhr-seitige Logik |

- Die iOS-App bettet die Uhr-App ein („Embed Watch Content“). In der Uhr-App steht `WKCompanionAppBundleIdentifier = com.roxo.famlist`. Die Uhr-App ist **nicht** als eigenständig markiert (`WKRunsIndependentlyOfCompanionApp = NO`), weil die Anmeldung über das iPhone läuft.
- Uhr-App und Widget-Erweiterung teilen die App Group `group.com.roxo.famlist.watch` für den Widget-Stand.
- Signierung: automatisch mit Team `YHSZ8G8RWJ` über `-allowProvisioningUpdates`.
- Die Targets lege ich per Ruby-Skript (`xcodeproj`) in `scripts/` an. Das Skript bleibt im Repo.
  - `scripts/watch_targets.rb` legt `FamlistWatch`, `FamlistWatchTests` und das Scheme `FamlistWatch` an. Außerdem gleicht es die geteilten Dateien aus `scripts/watch_shared_sources.txt` ab.
  - `scripts/add_files.rb` trägt neue Dateien in ein Target ein.
  - Die Widget-Erweiterung lege ich erst in Phase 6 an, weil sie ihre Widget-Views als Einstieg braucht.
- Die Schriften `Outfit-Variable.ttf` und `DMSans-Variable.ttf` kommen ins Uhr-Target (`UIAppFonts`), ebenso die Supabase-Konfiguration wie im iOS-Target.

---

## 4. Server-Änderungen

| Nr. | Änderung | Inhalt |
|---|---|---|
| Migration 022 | `migrations/022_catalog_usage.sql` | `item_catalog` bekommt `use_count int not null default 0` und `last_used_at timestamptz`. Dazu kommen ein Index für die Sortierung und die RPC `catalog_note_use(p_names text[])`. Die RPC zählt atomar für den angemeldeten Nutzer hoch, damit zwei Geräte sich nicht gegenseitig Zählungen überschreiben. Einträge ohne Treffer ignoriert sie. RLS bleibt wie in Migration 019. Prüfskript: `migrations/tests/022_catalog_usage_check.sql`. |
| Edge Function | `watch-session` | Die Function prüft den JWT (`verify_jwt: true`) und holt Konto und E-Mail mit `auth.getUser(jwt)` vom Auth-Server, nie aus der Anfrage. Mit `generateLink` (magiclink) erzeugt sie einen Code, prüft, dass er zum selben Konto gehört, und gibt **nur** `hashed_token` zurück. Pro Nutzer ist höchstens 1 Aufruf je 10 s erlaubt (sonst 429). Die Quelle liegt in `supabase/functions/watch-session/index.ts`. |
| Migration 024 | `migrations/024_ensure_default_list_rls.sql` | Fehlerbehebung, gefunden im Gerätepaar-Test: `ensure_default_list` scheiterte seit Migration 019 mit 403, sobald die Standardliste existierte. Jede Anmeldung ohne lokale Listen-Kopie (neues Gerät, Neuinstallation) brach ab. Prüfskript `migrations/tests/024_ensure_default_list_check.sql`. |
| Migration 023 | `migrations/023_watch_session.sql` | Die Aufruf-Grenze braucht einen Zeitpunkt je Konto, der zwischen Aufrufen erhalten bleibt; Edge Functions laufen in mehreren Instanzen ohne gemeinsamen Speicher. Tabelle `private.watch_session_requests` und RPC `watch_session_claim(p_user)` (atomar, nur `service_role`). Prüfskript: dasselbe wie für 022. |
| Client | Zähler | `ListViewModel.addItem` (auch „Menge +1“ bei gleichem Namen) und der Sammel-Import legen über die Offline-Warteschlange des Artikelstamms einen Auftrag `noteUse` ab, immer nach dem Speichern des Eintrags. Ohne Netz wird er nachgesendet; die lokale Kopie zählt sofort mit. Die Uhr nutzt in Phase 5 denselben Weg. |
| Client | Delta aller Listen | `fetchItemsSince(listIds:since:)`: ein Aufruf je Seite mit `list_id IN (…)`, eine gemeinsame Zeitmarke. Neu hinzugekommene Listen fragt die Uhr getrennt ab `.distantPast` ab. |
| Client | Realtime aller Listen (iPhone) | Ein Kanal je Liste, solange die App im Vordergrund ist (`keepListsInSync`). Nach jeder (Wieder-)Anmeldung holt die App das Delta dieser Liste in SwiftData; Änderungen meldet `setRemoteChangeHandler` (gebündelt, ohne Echos der eigenen Änderungen). Höchstens 90 Listen (Supabase: 100 Kanäle je Verbindung, belegt in der Doku „Realtime Quotas“). |

**„Oft gekauft“** zeigt die ersten 8 Einträge des Artikelstamms, sortiert nach `use_count` absteigend und dann nach `last_used_at`. Die Detailzeile zeigt die Kategorie, sonst die Menge, wie im Design („Milchprodukte“, „10 Stück“). Weil der Zähler bei 0 beginnt, ist die Liste anfangs nach `last_used_at` sortiert oder leer. Das ist unvermeidbar, denn es gibt keine historischen Daten.

---

## 5. Screens (pixelgenau nach `Watch*.dc.html`, Code aus `design-handoff/WatchUI`)

| Screen | Daten und Aktionen |
|---|---|
| Liste | Abschnitte nach Kategorie in Ladenweg-Reihenfolge; die Kategorien kommen vom Server wie auf dem iPhone. Tipp auf den Kreis hakt ab, mit Haptik `.sensoryFeedback(.success)`. Tipp auf die Zeile öffnet „Artikel“. „Alle abhaken“ sitzt unten links, der FAB öffnet „Hinzufügen“. Sind alle erledigt, erscheint „Alles erledigt“. |
| Artikel | Die Menge ändert sich per Digital Crown (`digitalCrownRotation`, 1–99) und über ＋/−. Gesendet wird erst, wenn die Krone ruht, damit nicht 20 Einzeländerungen entstehen. „Abhaken“ hakt ab und springt zurück. |
| Hinzufügen | Die Eingabe öffnet die System-Eingabe mit Diktat (`TextFieldLink`). Darunter steht „Oft gekauft“ (§4). Bei gleichem Namen gilt dieselbe Regel wie auf dem iPhone (deterministische ID): Ein abgehakter Artikel wird wieder offen, ein offener bekommt +1. |
| Alles erledigt | „Zurücksetzen“ hebt alle Haken auf (wie `toggleAllItems()`), gebündelt in einem Sende-Durchlauf. |
| Listen | Der Favorit steht oben, danach kommen die übrigen Listen alphabetisch. Tipp wechselt nur die Liste der Uhr. |
| Zifferblatt | Smart-Stack-Karte (`.accessoryRectangular`), Ring-Komplikation (`famlist://watch/list`) und Plus-Komplikation (`famlist://watch/add`). |

- **Bedienungshilfen:** Die VoiceOver-Labels folgen den `aria-label`s im HTML („Alle abhaken“, „Artikel hinzufügen“) und den Labels im Referenzcode. Artikelzeilen werden zu einem Element zusammengefasst, und abgehakte Zeilen tragen den Zustand. Bei großer Schrift wachsen Zeilen, statt abzuschneiden: `minHeight` statt fester Höhe, nur wo nötig. Diese Abweichung trage ich in PLAN.md §9 ein.
- **Nicht gestaltet** und deshalb schlicht im vorhandenen Stil, mit Eintrag in PLAN.md §9:
  - leere Liste
  - „Öffne Famlist auf dem iPhone, um die Uhr anzumelden“
  - Hinweis auf ungesendete Änderungen
- **Icons:** Kompiliert `SVGIcon` für watchOS, nutze ich die Original-Pfade, sonst SF Symbols. Das README erlaubt diese Ausnahme.
- **UserLog:** nur in den Uhr-ViewModels und in Deutsch.

---

## 6. Widgets und Komplikationen

- Die Uhr schreibt nach jeder Änderung einen kleinen Stand in den App-Group-Container: aktive Liste, Anzahl offen, Anteil erledigt. Danach ruft sie `WidgetCenter.shared.reloadTimelines(ofKind:)` auf.
- Der Timeline-Provider liest nur diesen Stand und stellt keine Netz-Abfrage.
- **Grenze:** watchOS begrenzt, wie oft Komplikationen neu gezeichnet werden. Bei vielen schnellen Änderungen kann die Anzeige kurz hinterherhinken; die App selbst ist davon nicht betroffen.

---

## 7. Tests

| Test | Ort | Szenario |
|---|---|---|
| `WatchMessageCodingTests` | FamlistTests | Jede WatchConnectivity-Nachricht übersteht Kodieren und Dekodieren. Eine unbekannte Version wird abgelehnt. |
| `WatchBridgeTests` | FamlistTests | Vom Uhr-Sofort-Weg empfangene Zeilen übernimmt das iPhone nur per `mergeRemote` und reiht sie **nicht** ein. Eine ältere HLC ändert nichts. Nach dem Abmelden geht `signOut` über den garantierten Weg. |
| `AllListsRealtimeTests` | FamlistTests | Ein Ereignis einer nicht aktiven Liste landet in SwiftData und wird weitergeleitet. |
| `MultiNodeSyncScenarioTests` | FamlistTests | Zwei SyncEngines mit **verschiedenen** HLC-Geräte-IDs (Uhr, iPhone) teilen ein Test-Repository, das LWW wie `upsert_items_lww` entscheidet. (1) Die Uhr ist offline und macht 3 Änderungen; wieder online kommen alle beim Server an, und das iPhone sieht sie nach der Delta-Abfrage. (2) Das iPhone ändert, während die Uhr offline ist; die Uhr übernimmt die Änderung, und eine eigene **neuere** ungesendete Änderung bleibt stehen und gewinnt. (3) Beide ändern denselben Artikel gleichzeitig; beide Geräte landen beim selben Endstand (höhere HLC). |
| `CatalogUsageTests` | FamlistTests | Hinzufügen erzeugt einen Zähl-Auftrag, auch offline; die Sortierung von „Oft gekauft“ stimmt. |
| Uhr-Tests | FamlistWatchTests | Sitzungsaufbau mit Test-Client, Delta-Übernahme, Abmelden leert den Speicher, Widget-Stand wird geschrieben. |
| SQL | `migrations/tests/022_…` | RPC zählt nur für den eigenen Nutzer, zwei Aufrufe ergeben +2, ein fremder Nutzer kann nicht zählen. |
| Live | FamlistUITests (`TEST_RUNNER_FAMLIST_LIVE=1`) | `watch-session` liefert für das Testkonto einen Code, und `verifyOTP` ergibt eine zweite Sitzung. Die erste Sitzung bleibt gültig. |
| Pixelvergleich | Skript | Screenshots vom Simulator (46 mm, 208 × 248) gegen die gerenderten `.dc.html`. |
| Gerätetest | Roberts Ultra und iPhone | Flugmodus an der Uhr, 3 Aktionen, Flugmodus aus: alles kommt an. Zusätzlich ohne iPhone (WLAN und Bluetooth **in den Einstellungen** aus, laut TN3135): Die Uhr sendet selbst. Beides geht nur auf Geräten, weil der Simulator WebSockets erlaubt und kein `transferUserInfo` kennt. |

---

## 8. Phasen (je Phase: Build grün für iOS und watchOS, Tests grün, ein Commit, Push nur nach Okay)

| Phase | Inhalt | Fertig, wenn |
|---|---|---|
| 1 | Targets per Skript, App Group, Einbettung, Schriften, geteilte Kerndateien im Uhr-Target (minimal aufgetrennt), leere Uhr-App | `xcodebuild` für iOS und watchOS grün; alle bisherigen Tests grün |
| 2 | Designsystem (`WatchTheme`, Bausteine) und 5 Screens mit Beispieldaten; eine Type je Datei; `#Preview` je Screen | Pixelvergleich gegen `.dc.html` bestanden |
| 3 | Server: Migration 022 und Edge Function `watch-session` (live, mit Prüfskripten). iPhone: Zähl-Auftrag beim Hinzufügen, `fetchItemsSince(listIds:)`, Realtime für alle Listen | SQL-Prüfung und Unit-Tests grün, Live-Test Sitzung grün |
| 4 | Sync-Schicht der Uhr: `WatchConnectivityService` auf beiden Seiten, `WatchBridge` (iPhone), Sitzungsaufbau, eigene SyncEngine, Abfrage-Takt, Abmelden und Kontowechsel | Szenario-Tests (§7) grün; im Simulator-Paar erscheint Abhaken auf dem anderen Gerät |
| 5 | Uhr-ViewModels und echte Daten in den Screens: Haptik, Krone, Hinzufügen mit Diktat und „Oft gekauft“, Zurücksetzen, Listenwahl, UserLog | Uhr-Tests grün, Screenshots mit echten Daten |
| 6 | Widgets und Komplikationen, App-Group-Stand, Deep Links, Hintergrund-Aktualisierung | Komplikationen sichtbar, Deep Links öffnen den richtigen Screen |
| 7 | Bedienungshilfen und Dynamic Type, Gerätetest auf der Ultra, PLAN.md §9 und SPEC ergänzen | Roberts Abnahme |

---

## 9. Entschiedene Fragen

1. Eigener Supabase-Zugang: **jetzt** (§2).
2. „Oft gekauft“: **Migration 022**, Zähler beim Hinzufügen (§4).
3. Aktive Liste: **je Gerät**; alle Listen bleiben synchron (§2).

Offene Blocker gibt es derzeit keine.

## 10. Risiken

| Risiko | Folge | Gegenmittel |
|---|---|---|
| Die Edge Function arbeitet mit dem Service-Schlüssel | Ein Fehler darin könnte Sitzungen für fremde Konten erzeugen | Die E-Mail kommt **nur** aus dem geprüften JWT, nie aus der Anfrage; dazu Aufruf-Grenze und ein Live-Test mit falschem Token |
| Die Uhr-Sitzung wird widerrufen (z. B. „überall abmelden“) | Die Uhr kann nicht mehr senden | Die Warteschlange bleibt liegen, die Uhr fordert beim nächsten Kontakt mit dem iPhone einen neuen Code an, und nichts geht verloren |
| Mehr Realtime-Kanäle auf dem iPhone (einer je Liste) | Mehr Last und Akkuverbrauch | Die Kanäle laufen nur im Vordergrund wie heute. Supabase erlaubt 100 Kanäle je Verbindung (geprüft 26.09.2026, Doku „Realtime Reports/Quotas“); die App abonniert höchstens 90 Listen. Kanal-Anmeldungen: Free-Plan 100 je Sekunde je Projekt. |
| Abfrage alle 10 s auf der Uhr | Akku | Nur solange die App sichtbar ist, ein Aufruf für alle Listen, und die Antwort ist bei 0 Änderungen leer |
| Geteilte Dateien brechen den iOS-Build | Rückschritt im iPhone-Target | Nach jeder Phase laufen alle 606 Unit- und 40 UI-Tests |
| Automatische Signierung muss App Group und App-IDs erst registrieren | Der erste Geräte-Build scheitert | `-allowProvisioningUpdates`; zur Not legt Robert die Gruppe im Developer-Portal an |
| An der Uhr muss der Entwicklermodus an sein | Keine Installation auf der Ultra | Robert schaltet ihn einmalig in den Uhr-Einstellungen ein |
| Parallel arbeitende Session im selben Arbeitsbaum | Konflikte in der pbxproj | Vor jedem Commit `git status` prüfen; pbxproj-Änderungen nur per Skript |
