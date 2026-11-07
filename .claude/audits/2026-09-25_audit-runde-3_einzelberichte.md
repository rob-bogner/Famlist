# Audit-Runde 3 – Einzelberichte der 7 Prüfer
Stand: Branch audit-fixes, HEAD 7d54889, 25.09.2026. Alle Prüfer arbeiteten nur lesend.
Von Claude selbst nachgeprüft: S1/R1 (Code), A3/R3 (Code), A15/C2 (Formatter liefert nil bei Mikrosekunden; Postgres to_jsonb liefert Mikrosekunden – live geprüft), R2 (Absturz per swift nachgestellt).

---

## Architektur & Schichten (A)

# Architektur-Audit Famlist (Branch audit-fixes, HEAD 7d54889)

Ich habe nur gelesen. Ich habe keine Datei geändert, nichts committet und nichts in die Datenbank geschrieben. Gezählt habe ich 387 Swift-Dateien, davon 333 App-Dateien mit 33.516 Zeilen; die übrigen 54 Dateien sind Tests.

## Befunde, nach Schwere sortiert

**A1 · hoch · Der Abgleich ist auf drei Schichten verteilt**
- **Wo:** `Core/Sync/SyncEngine.swift`, `Features/ShoppingList/ViewModels/ListViewModel+RealtimeSync.swift:122-141`, `ListViewModel+Pagination.swift:52-56`, `ListViewModel+Reconcile.swift:48-53`, `Repositories/Implementations/SupabaseItemsRepository.swift:82`, `Core/Sync/RealtimeEventProcessor.swift:62-64`
- **Beleg:** Die SyncEngine sendet nur die lokalen Änderungen an den Server. Das Holen vom Server liegt im ListViewModel: `runIncrementalSync` ruft `itemStore.mergeRemote` und `itemStore.save()` auf, genauso `loadNextPage` und `removeVanishedItems`. Die Live-Änderungen verarbeitet das Repository. Es erzeugt dafür selbst `RealtimeEventProcessor(itemStore:)`, und dieser schreibt in SwiftData. Mindestens 7 Dateien aus 3 Schichten schreiben in den Artikel-Speicher.
- **Warum ein Problem:** Die Regel „neuere HLC gewinnt“ muss an drei Stellen gleich angewendet werden. Die HLC ist die Zeitmarke, die bei Konflikten entscheidet. Außerdem hängt die Richtung falsch herum: Das Repository hängt von der Sync-Schicht ab, und die Sync-Schicht hängt vom Repository ab. Den Datenabgleich kann man nicht ohne das ViewModel testen.
- **Empfehlung:** Ein eigener Baustein für das Holen vom Server soll Delta-Abgleich, Seitenladen, Aufräumen und Live-Ereignisse übernehmen. Er kann in die SyncEngine oder in einen eigenen `RemotePullCoordinator`. Das Repository liefert dann nur noch Daten. Das ViewModel ruft nur noch `sync.refresh(listId)` auf.
- **Sicherheit:** verifiziert.

**A2 · hoch · Fünf getrennte Offline-Warteschlangen mit unterschiedlichen Regeln**
- **Wo:**
  - Artikel: `Core/Sync/OperationQueue.swift` (SwiftData, mit HLC)
  - Listen: `Repositories/Offline/ListLocalStore.swift` (JSON-Datei)
  - Artikelstamm: `CatalogLocalStore.swift` (JSON-Datei)
  - Kategorien: `Features/Categories/ViewModels/CategoryStore.swift:59-68` (UserDefaults)
  - Preise: `Features/Receipts/ViewModels/PriceBook.swift:31,48-53` (UserDefaults)
- **Beleg:** Nur die Artikel nutzen eine HLC. Die anderen vier Warteschlangen senden ihre Aufträge einfach der Reihe nach, und der Server übernimmt den zuletzt gesendeten Stand. Listen liegen sogar doppelt auf dem Gerät. Das ListViewModel schreibt sie als `ListEntity` in SwiftData (`ListViewModel+ListManagement.swift:45,82,116`). Das `OfflineListsRepository` hält sie zusätzlich in der JSON-Datei. Beim Abmelden zählt `AppSessionViewModel+SignOut.swift:51-70` die offenen Aufträge über Typumwandlungen auf die konkreten Klassen zusammen. Solche Umwandlungen gibt es 7-mal: `AppSessionViewModel.swift:179`, `+SignOut:53,54,67,68`, `ListViewModel+Configuration.swift:25`, `ListViewModel.swift:280`. Preise und Kategorien kommen über die Rückruf-Registrierung in `FamlistApp.swift:135-137` dazu.
- **Warum ein Problem:** Jede neue Warteschlange muss man an drei Stellen von Hand anmelden: beim Senden, beim Zählen und beim Löschen. Vergisst man eine, gehen beim Abmelden ungesendete Änderungen ohne Rückfrage verloren. Für zwei gleichzeitige Änderungen an derselben Liste gibt es keine Regel, welche gewinnt.
- **Empfehlung:** Ein gemeinsames Protokoll `OfflineOutbox` mit `pendingCount`, `flush()` und `clearLocalData()` einführen. Alle fünf Speicher registrieren sich in einer zentralen Stelle. Die Listen sollen nur einen einzigen lokalen Speicher haben.
- **Sicherheit:** verifiziert. Der Datenverlust bei einer vergessenen Anmeldung ist abgeleitet (plausibel).

**A3 · hoch · Keine Schema-Versionierung, und eine gescheiterte Migration verwirft ungesendete Artikel-Änderungen**
- **Wo:** `Core/Storage/PersistenceController.swift:32-36` und `:58-70`
- **Beleg:** `VersionedSchema` und `SchemaMigrationPlan` kommen im Code 0-mal vor. Scheitert das Öffnen der Datenbank, schiebt `recover()` die Datei beiseite (`moveAside`) und legt eine leere Datenbank an. Die Artikel-Warteschlange `SyncOperation` liegt in derselben Datenbank.
- **Warum ein Problem:** Eine Modelländerung, die SwiftData nicht automatisch umstellen kann, macht die alte Datenbank unlesbar. Dann verschwinden alle offline gemachten Artikel-Änderungen, die noch nicht gesendet wurden. Der Nutzer bekommt keinen Hinweis.
- **Empfehlung:** Den jetzigen Stand als `SchemaV1` festhalten und einen `SchemaMigrationPlan` einführen. Vor dem Beiseiteschieben sollte man die Warteschlange aus der alten Datei retten oder den Nutzer informieren.
- **Sicherheit:** Der Code ist verifiziert. Die Folge ist abgeleitet (plausibel).

**A4 · hoch · ListViewModel ist ein God-Type, der nur auf 20 Dateien verteilt wurde**
- **Wo:** `Features/ShoppingList/ViewModels/ListViewModel*.swift`
- **Beleg:**
  - 2.619 Zeilen in 20 Dateien
  - 17 `@Published`-Eigenschaften und etwa 24 weitere gespeicherte Eigenschaften
  - 10 Abhängigkeiten (Repository, SyncEngine, ListsRepository, Artikelstamm, globaler Katalog, itemStore, listStore, SyncOrchestrator, PageLoader, ImagePrefetcher)
  - 94 Funktionen
  - Verantwortlichkeiten: Artikel anlegen/ändern/löschen, Massenaktionen, Rückgängig beim Löschen, Listenverwaltung, Duplizieren, Mitgliedschaften, Live-Abgleich, Delta-Abgleich, Seitenladen, Aufräumen, Sortierung und Abschnitte, Kategorien, Artikelstamm-Änderungen, Fotos, Einkauf-erledigt-Ereignis, Zurücksetzen beim Abmelden
  - Auch der Artikelstamm-Bildschirm (ItemManagement) hängt an diesem ViewModel: `ListViewModel` wird dort in 5 Dateien genutzt.
- **Warum ein Problem:** Die Extensions teilen sich denselben veränderlichen Zustand. Jede Änderung kann jede andere Funktion betreffen. Tests müssen immer das ganze Objekt aufbauen.
- **Empfehlung:** Echte Teile herauslösen, jeweils mit eigenem Zustand:
  - `ListsViewModel` (Listenverwaltung, Mitgliedschaften)
  - `ItemListViewModel` (Artikel, Sortierung, Abschnitte, Rückgängig)
  - Pull-Koordinator aus A1 (Abgleich)
  - `BulkActionService` (Massenaktionen)
- **Sicherheit:** verifiziert.

**A5 · mittel · AppSessionViewModel mischt etwa 9 Aufgaben und greift durch andere Objekte hindurch**
- **Wo:** `App/AppSessionViewModel*.swift` (823 Zeilen in 6 Dateien, 12 `@Published`)
- **Beleg:**
  - Aufgaben: Anmeldung (Magic-Link, Apple, E-Mail/Passwort), Sitzung wiederherstellen, Einladungen und Links, Profil, Avatar, Benachrichtigungen, Favoriten, Konto löschen, Abmelden, Toasts.
  - Es richtet ein anderes ViewModel ein: `listViewModel.configure(listsRepository: lists)` in `+Auth.swift:146`.
  - Es greift durch andere Objekte hindurch: `listViewModel.syncEngine?.pendingOperations` (`+SignOut.swift:66`) und `authService?.client.auth.currentUser?.email` (`AppSessionViewModel.swift:58`).
  - Es erzeugt `AuthService` und `OnboardingService` selbst (`:128-134`), statt sie übergeben zu bekommen.
  - Es importiert `Supabase` für `PostgrestError` (`+Auth.swift:178`).
- **Warum ein Problem:** Die Anmeldung kann man nicht ohne das ListViewModel testen. Die Dienste lassen sich im Test nicht austauschen.
- **Empfehlung:** `ProfileViewModel` und `InviteCoordinator` abtrennen. Die Dienste im Initializer übergeben. Das Abmelden an die Outbox-Stelle aus A2 abgeben.
- **Sicherheit:** verifiziert.

**A6 · mittel · Die Supabase-Fassade lässt Supabase-Typen und -Fehler durch**
- **Wo:** `Core/Networking/SupabaseClient.swift:74-84,123-139`
- **Beleg:** Das Protokoll `SupabaseClienting` gibt `PostgrestQueryBuilder`, `RealtimeClientV2`, `User`, `Session` und `AuthChangeEvent` nach außen. Supabase-Fehlertypen werden außerhalb der Repositories an 5 Stellen ausgewertet:
  - `AppSessionViewModel+Auth.swift:178`
  - `Sharing/Models/InviteError.swift:39`
  - `Core/Utils/UserFacingError.swift:42-45`
  - `Core/Sync/SyncErrorClassifier.swift:39`
  - `OfflineListsRepository` (importiert `Supabase`)
- **Warum ein Problem:** Der Kommentar verspricht, dass der Rest der App keine Supabase-Typen sieht. Das stimmt nicht. Ein Update des SDK betrifft deshalb ViewModels und Modelle.
- **Empfehlung:** Die Repositories übersetzen Fehler in eigene Fehlertypen der App, zum Beispiel `RepositoryError.notFound/.permission/.network`. `from(_:)` und `realtime` bleiben nur im Repository-Modul sichtbar.
- **Sicherheit:** verifiziert.

**A7 · mittel · Das ListsRepository-Protokoll ist zu breit, mischt Datenbankzeilen mit App-Modellen und verdoppelt die Umwandlung**
- **Wo:** `Repositories/Protocols/ListsRepository.swift:30-110`, `Repositories/Models/List.swift`
- **Beleg:**
  - Das Protokoll hat 17 Methoden. Ein Teil gibt die Datenbankzeile `List` zurück (Felder `owner_id`, `is_default`), ein anderer Teil das App-Modell `ListModel`.
  - Die Standardversion `createList(id:for:title:)` ignoriert die übergebene `id` (`:134`).
  - Die Umwandlung `List` → `ListModel` steht an 8 Stellen, darunter zwei ViewModels: `ListViewModel+ListManagement.swift:77` und `+Duplicate.swift:48`.
  - Der Name `struct List` verdeckt `SwiftUI.List`, und das app-eigene `AuthError` kollidiert mit `Auth.AuthError` (`UserFacingError.swift:42-43`).
  - `InvitePreviewRow` mit Datenbank-CodingKeys liegt in der Protokolldatei.
- **Empfehlung:** Das Protokoll gibt nur noch `ListModel` zurück. Die Datenbankzeile wird `private` in der Supabase-Implementierung. `List` in `ListRow` umbenennen. Die Standardversion ohne `id` löschen.
- **Sicherheit:** verifiziert.

**A8 · mittel · Stille Standardversionen in Protokoll-Extensions verdecken fehlende Implementierungen**
- **Wo:**
  - `SupabaseClient.swift:141-150`: `rpc` und `storageRemove` tun nichts, `rpcRows` liefert `[]`.
  - `Core/Sync/SyncEngineProtocol.swift:91-100`: `pendingOperations = 0`, `resetForSignOut() {}`.
  - `ListsRepository.swift:149-154`
- **Warum ein Problem:** Das sind Standardversionen für Testattrappen, aber sie gelten auch für echte Implementierungen. Vergisst eine neue Engine `pendingOperations`, meldet die Rückfrage beim Abmelden „0 ungesendet“. Dann werden Daten verworfen.
- **Empfehlung:** Standardversionen in Testattrappen verschieben, zum Beispiel in eine `TestDoubleDefaults`-Extension im Test-Target. Pflichtmethoden ohne Standard lassen.
- **Sicherheit:** Der Code ist verifiziert. Die Folge ist abgeleitet (plausibel).

**A9 · mittel · Die Abhängigkeitsrichtung ist umgekehrt: Core hängt an Features**
- **Wo:**
  - Modelle: `Features/ItemManagement/Models/ItemModel.swift`, `Features/ShoppingList/Lists/Models/ListModel.swift`, `Features/Categories/Models/CategoryDefinition.swift`, `Features/Receipts/Models/PricePoint.swift`
  - `Core/Sync/SyncEngineProtocol.swift:67` nutzt `ImportTarget` aus `Features/ItemManagement/Services/ImportMergeService.swift:31`.
- **Beleg:** `ItemModel` kommt in 16 Dateien unter Core, Repositories und Models vor, `ListModel` in 8. Das @Model `SyncOperation` liegt in `Core/Sync`, nicht in `Models/`.
- **Warum ein Problem:** Die Fachmodelle liegen in Feature-Ordnern. Man kann die Features deshalb nicht in eigene Module auslagern, und die Ordnerstruktur zeigt die echte Schichtung nicht.
- **Empfehlung:** Einen Ordner `Domain/` (oder `Models/Domain`) für ItemModel, ListModel, CategoryDefinition, PricePoint, Measure und ImportTarget anlegen. `SyncOperation` nach `Models/` verschieben.
- **Sicherheit:** verifiziert.

**A10 · mittel · Features hängen im Kreis voneinander ab, und gemeinsame Design-Bausteine liegen in Feature-Ordnern**
- **Beleg:** Ich habe öffentliche Typnamen quer über die Feature-Ordner gezählt. Kreise:

  | Kreis | Hinweg | Rückweg |
  |---|---|---|
  | ShoppingList ↔ ItemManagement | 14 Typen | 5 Typen (u. a. `ListViewModel`, `ShoppingListView`) |
  | ItemManagement ↔ Categories | 4 Typen | 2 Typen |
  | Receipts ↔ ItemManagement | 3 Typen | 1 Typ |
  | ShoppingList ↔ Account | 11 Typen | 1 Typ |

  Dazu kommen gemeinsame Design-Bausteine in Feature-Ordnern: `Features/Onboarding/Design/EKK*` wird von Receipts (8 Typen) und Categories (5 Typen) genutzt. `Features/Account/Design/ListAccount*` wird von Sharing (7 Typen) und ShoppingList (11 Typen) genutzt.
- **Warum ein Problem:** Features kann man nicht getrennt ändern oder testen. „Onboarding“ ist in Wahrheit eine Komponentenbibliothek.
- **Empfehlung:** `EKK*`, `ListAccount*` und `ItemExtra*` nach `Shared/Components` verschieben. `ItemManagement` darf `ListViewModel` nicht kennen, sondern bekommt Callbacks oder ein schmales Protokoll.
- **Sicherheit:** Die Zählung ist verifiziert. Sie arbeitet über Typnamen und kann einzelne Namensgleichheiten mitzählen.

**A11 · mittel · Abhängigkeiten werden nachträglich über `configure(...)` gesetzt, mit Pflicht-Reihenfolge**
- **Wo:** `ListViewModel+Configuration.swift` (7 `configure`-Methoden), `ListViewModel.swift:114,122,126,130,151,154,191`, `AppSessionViewModel+Auth.swift:146-149`
- **Beleg:**
  - `internal var syncEngine: (any SyncEngineProtocol)?` trägt den Kommentar „Always non-nil at runtime“.
  - Zu `startObservingMemberships` steht der Kommentar „muss nach configure(listsRepository:) aufgerufen werden … sonst startet die Observation nicht (RC-5)“.
  - Rückrufe mit nur einem Platz werden beim nächsten Setzen überschrieben: `onListsVanished` und `onFlushed` (`OfflineListsRepository.swift:36,38`), `onBudgetExceeded` (`SyncOrchestrator.swift:46`), `setReconnectHandler`, `setLocalWriteObserver`.
- **Warum ein Problem:** Der Compiler prüft die Vollständigkeit nicht. Eine falsche Reihenfolge führt still zu fehlenden Funktionen.
- **Empfehlung:** Alle Pflicht-Abhängigkeiten im Initializer übergeben. Ereignisse als `AsyncStream` anbieten, damit mehrere Stellen zuhören können.
- **Sicherheit:** verifiziert.

**A12 · mittel · Views bauen ViewModels und verbinden ViewModels untereinander**
- **Wo:** `ShoppingListView+Sheets.swift:98-110,145-148,205-209`, `ShoppingListView.swift:103`
- **Beleg:**
  - Die View holt `listViewModel.catalogRepository`, `listViewModel.listsRepository` und `session.profiles` und baut daraus `ItemSearchViewModel`, `BarcodeScanViewModel`, `ShareMembersViewModel` und `ManageItemsViewModel`.
  - Die View kopiert Zustand von einem ViewModel ins andere: `.onReceive(categoryStore.$categories) { listViewModel.categoryOrder = $0 }`.
  - `saveCatalogEdit` steuert zwei ViewModels gleichzeitig.
- **Warum ein Problem:** Das ListViewModel wird so zum Service-Locator, also zu einer Stelle, bei der sich andere ihre Abhängigkeiten abholen. Die Logik, wie Objekte zusammengesetzt werden, ist über Views verstreut. Zustand liegt doppelt vor.
- **Empfehlung:** Eine `ViewModelFactory` (oder ein `AppContainer`) im Environment bereitstellen. Die Kategorie-Reihenfolge direkt aus `CategoryStore` lesen.
- **Sicherheit:** verifiziert.

**A13 · mittel · Die Artikelanzeige wird auf zwei Wegen aktualisiert und durch vier Sperr-Merker geschützt**
- **Wo:** `ListViewModel+RealtimeSync.swift:57-97`, `ListViewModel.swift:158,168,173,179`
- **Beleg:** Der erste Weg ist ein `AsyncStream`-Schnappschuss aus `repository.observeItems`. Der zweite Weg sind 20 direkte Aufrufe von `refreshItemsFromStore()`. Dazu kommen vier Merker gegen Wettläufe zwischen beiden Wegen: `isBulkDeleting`, `isBulkMutationActive`, `pendingBulkDeleteIDs` und `pendingAnimatedItemIDs`.
- **Warum ein Problem:** Die Liste auf dem Bildschirm ist eine Kopie von SwiftData, die man von Hand nachführen muss. Jede neue Schreibstelle braucht wieder einen Merker.
- **Empfehlung:** Nur einen Weg nutzen: SwiftData beobachten, entweder mit `@Query` oder mit einem Store, der Änderungen meldet. Das Repository liefert dann keine lokalen Schnappschüsse mehr.
- **Sicherheit:** verifiziert.

**A14 · mittel · Zwei nahezu gleiche Offline-Speicher mit unterschiedlicher Fehlerbehandlung**
- **Wo:** `Repositories/Offline/CatalogLocalStore.swift` und `ListLocalStore.swift`; `OfflineItemCatalogRepository.swift:131-155` und `OfflineListsRepository.swift:158-185`
- **Beleg:** Nach dem Umbenennen der Typnamen unterscheiden sich die beiden Speicher nur in Dateinamen und Kommentaren. Der Kommentar sagt selbst: „Gleiches Muster wie CatalogLocalStore“. `flush()` ist Zeile für Zeile gleich. `drain()` weicht ab:

  | | Artikelstamm | Listen |
  |---|---|---|
  | Netzfehler erkennen | `catch let error as URLError` | `SyncErrorClassifier` |
  | Aufgeben | nach `maxFailures` Fehlversuchen | bei dauerhaften Fehlern sofort |
- **Warum ein Problem:** Derselbe Serverfehler führt je nach Warteschlange zu Wiederholen oder Verwerfen.
- **Empfehlung:** Einen generischen `LocalOutboxStore<Entry, Operation>` und einen gemeinsamen `OutboxDrainer` bauen, der `SyncErrorClassifier` nutzt.
- **Sicherheit:** verifiziert.

**A15 · mittel · Artikelzeilen werden zweimal verschieden eingelesen**
- **Wo:** `Core/Sync/RealtimeEventProcessor.swift:98-261` (164 Zeilen, liest Felder einzeln aus `[String: Any]`) und `Repositories/Implementations/SupabaseItemRow.swift:68-104` (`Decodable`)
- **Beleg:** Der Live-Weg nutzt `ISO8601DateFormatter()` ohne `.withFractionalSeconds` (`:36`). Der Server erzeugt die Nachricht mit `to_jsonb(NEW)` (`migrations/017_realtime_broadcast.sql:41`). Das liefert Zeitstempel mit Mikrosekunden. `SupabaseItemRow` versucht dagegen beide Formate.
- **Warum ein Problem:** Wahrscheinlich wird `created_at` bei Live-Ereignissen zu `nil`. Ein neuer Artikel bekommt dann die Empfangszeit des Geräts (`ItemEntity+Mapping.swift:142`). Das beeinflusst die Sortierung „Zuletzt hinzugefügt“.
- **Empfehlung:** Die Nachricht mit `JSONSerialization` in `Data` umwandeln und mit `SupabaseItemRow` dekodieren. Dann gibt es nur noch einen Einlese-Weg.
- **Sicherheit:** Der Code ist verifiziert. Die Folge `created_at = nil` ist abgeleitet (plausibel), nicht zur Laufzeit geprüft.

**A16 · mittel · Vorschau-Code im Release, und ohne Konfiguration startet die App still im Demo-Modus**
- **Wo:** `App/FamlistApp.swift:138-161`, `Repositories/Implementations/PreviewRepositories.swift`, `Core/Sync/PreviewSyncEngine.swift`, `Shared/Resources/PreviewMocks.swift`
- **Beleg:** Keine dieser Dateien steckt in `#if DEBUG`. Fehlt `SupabaseConfig`, startet auch ein Release-Build mit `PreviewItemsRepository`, `PreviewSyncEngine` und `CategoryStore(repository: nil)`.
- **Warum ein Problem:** Ein falsch gebauter Release verhält sich wie eine funktionierende App. Er synchronisiert aber nie, und niemand merkt es.
- **Empfehlung:** Vorschau-Typen in `#if DEBUG` stecken. Im Release bei fehlender Konfiguration einen Fehlerbildschirm zeigen.
- **Sicherheit:** verifiziert.

**A17 · mittel · Parallele Design-Systeme und eine zweite Kopie der Listenansicht**
- **Beleg:**
  - 7 Theme- und Token-Typen: `ColorTheme`, `ListTheme`, `SheetTheme`, `OverlayTheme`, `ListAccountTokens`, `EKKTokens`, `ItemExtraTokens`.
  - 5 Icon-Enums. 9 SVG-Pfade stehen mehrfach im Code, zum Beispiel `camera` in `EKKIcon` und `ListAccountIcon`.
  - `Shared/Components/Hybrid/Design/` enthält 925 Zeilen. Diese Bausteine kopieren die echten Listen-Bausteine: `DesignProgressHero`/`ProgressHero`, `DesignItemRow`/`ItemCard`, `DesignListTopBar`/`ListTopBar`, `DesignListTabs`/`ListFilterTabs`, `DesignListEmptyState`/`ListEmptyState`, `DesignSectionHeader`/`ListSectionHeader`, `DesignListSearchField`/`ListSearchBar`.
  - `DesignListScreen` steckt in 10 App-Views als Hintergrund für den Fall „nicht gehostet“, also für die Vorschau. Beispiele: `SettingsSheet.swift:47`, `OverlayStage.swift:47`.
- **Warum ein Problem:** Jede Design-Änderung an der Liste muss man zweimal machen. Sonst zeigen die Vorschauen einen veralteten Stand.
- **Empfehlung:** Die Vorschau-Hintergründe aus den echten Bausteinen mit Beispieldaten zusammensetzen. Tokens und Icons in `Core/DesignSystem` zusammenführen.
- **Sicherheit:** verifiziert.

**A18 · mittel · Die Repositories laufen uneinheitlich auf dem Main Actor, und SwiftData läuft nur dort (bekannter Befund bestätigt)**
- **Beleg:** 5 Protokolle sind `@MainActor`: Items, Lists, ItemCatalog, GlobalCatalog, ImageStorage; dazu `SyncEngineProtocol`. 3 Protokolle sind `Sendable` ohne Main Actor: Profiles, PricePoints, CategoryDefinitions. `SwiftDataItemStore` ist `@MainActor` (`:21`). Alle Stores nutzen `modelContainer.mainContext` (`FamlistApp.swift:58-85`). `ModelActor` kommt 0-mal vor.
- **Bekannter Befund:** Die Fotos liegen als Base64 in SwiftData und werden auf dem Main-Thread verarbeitet. Das trifft weiter zu, belegt durch `ItemEntity.swift:35` (`imageData: String?`).
- **Empfehlung:** Einen `@ModelActor`-Store für Abgleich und Fotos einführen. Eine einheitliche Regel für die Isolation der Repositories festlegen.
- **Sicherheit:** verifiziert.

**A19 · niedrig · Doppelte Sortierung über eine statische Variable, die sich nie ändert**
- **Wo:** `ListViewModel+BulkActions.swift:31,89`
- **Beleg:** `static var currentSortOrder: SortOrder = .category` wird nur in `ListViewModel.swift:295` gesetzt, und zwar wieder auf `.category`. Trotzdem wird sie an 5 Stellen angewendet. Danach sortiert `ListSectionBuilder` erneut nach `sortSettings` (`ListViewModel+Sections.swift:26`). Das Enum `SortOrder` ist in einer ViewModel-Extension deklariert.
- **Empfehlung:** Die statische Variable löschen. `SortOrder` in eine eigene Datei unter `Models/` verschieben.
- **Sicherheit:** verifiziert.

**A20 · niedrig · Der Namensschlüssel für Artikel wird uneinheitlich gebildet**
- **Wo:** `Core/Sync/ItemIdentity.swift:41` und `UUID+DeterministicItemID.swift:49` (doppelt vorhanden, mit Unicode-NFC-Normalisierung) gegenüber `Features/Receipts/Models/PricePoint.swift:40` und `Repositories/Offline/CatalogOperation.swift:55` (ohne NFC)
- **Warum ein Problem:** NFC bringt Umlaute in eine einheitliche Zeichenfolge. Ohne NFC kann „Äpfel“ in zerlegter Schreibweise bei Artikeln passen, bei Preisen und im Artikelstamm aber nicht.
- **Empfehlung:** Überall `ItemIdentity.normalizedKey` verwenden.
- **Sicherheit:** Der Code ist verifiziert. Die Folge ist abgeleitet (plausibel).

**A21 · niedrig · Doppelte Hilfsfunktionen für Anzeige und Format**
- **Beleg:**
  - Der Ausdruck `.formatted(.currency(code: "EUR").locale(de_DE))` steht 5-mal im Code. Es gibt dafür zwei Hilfsfunktionen: `PriceHistoryViewModel.euro(Decimal)` (`:69`) und `PriceDisplaySetting.euro(Double)` (`:30`). Preise haben zwei Typen: `Decimal` in `PricePoint`, `Double` in `ItemModel`.
  - Der Anzeigename `[brand, name].compactMap…joined(" ")` wird 6-mal zusammengebaut: `ListViewModel+ItemCRUD.swift:41,120,197,229`, `+ItemStatus.swift:67`, `PriceHistorySheet.swift:52`.
- **Empfehlung:** `ItemModel.displayName` und einen `Money`-Formatter einführen.
- **Sicherheit:** verifiziert.

**A22 · niedrig · Toter Code und tote Verdrahtung**
- **Beleg:**
  - `SyncMonitor` wird als `environmentObject` eingesetzt (`FamlistApp.swift:191`), aber keine View liest es.
  - `SyncEngine.syncStatus` ist `@Published` (`:42`), wird aber nirgends gelesen.
  - `AuthViewModel` (138 Zeilen) wird nur in Tests genutzt. `signUpWithEmailPassword` ruft nur dieses tote ViewModel auf.
  - `ListViewModel.selectedItem` wird nirgends genutzt.
  - Die `Codable`-Umsetzung von `ItemEntity` und `ListEntity` wird nirgends aufgerufen.
  - `ListEntity.syncStatus` wird geschrieben (`ListViewModel+ListManagement.swift:266`), aber für den Abgleich nie gelesen.
  - 3 leere Ordner: `Account/ViewModels`, `Authentication/Models`, `ShoppingList/Lists/ViewModels`.
- **Empfehlung:** Löschen oder bewusst anbinden.
- **Sicherheit:** verifiziert.

**A23 · niedrig · Versteckte Singletons trotz Dependency Injection**
- **Beleg:**
  - `ConnectivityMonitor.shared` wird in `FamlistApp.swift:95` und `AppSessionViewModel+SignOut.swift:57` direkt genutzt, obwohl der Monitor schon injiziert wird.
  - `ImageCache.shared` steckt in einer Modell-Extension (`ItemModel+Display.swift:30`, damit hängt das Modell an UIKit) und in `ItemFormViewModel.swift:86`.
  - `UserDefaults.standard` wird direkt in 3 ViewModel-Extensions genutzt.
- **Warum ein Problem:** Tests können „offline beim Abmelden“ nicht nachstellen.
- **Empfehlung:** Den Netzstatus, den Cache und `UserDefaults` übergeben.
- **Sicherheit:** verifiziert.

**A24 · niedrig · Verstöße gegen die CLAUDE.md-Regeln**
- **One type per file:** 44 Dateien haben mehr als einen Typ auf oberster Ebene. Schwerwiegend ist, dass Implementierungen in Protokolldateien liegen:
  - `SupabaseImageStorage` in `Protocols/ImageStorage.swift:31`
  - `PreviewItemsRepository` in `Protocols/ItemsRepository.swift:84`
  - `InMemoryPricePointsRepository`, `InMemoryCategoryDefinitionsRepository`, `PreviewItemCatalogRepository`, `PreviewGlobalProductCatalogRepository`
  - 5 Typen in `SupabaseClient.swift`
- **Falscher Ordner:** `SimulatorAuthHelper` liegt im Ordner `ViewModels` (`AuthTestHelpers.swift`).
- **Dateien über 300 Zeilen:** nur `SyncEngine.swift` mit 304 Zeilen.
- **GCD:** Es gibt nur 2 berechtigte Queues, für `NWPathMonitor` und die Kamera.
- **Completion-Handler:** 1 Stelle, `ListViewModel+ListManagement.swift:67`.
- **Überflüssige Aufrufe:** `await MainActor.run` steht 16-mal in Klassen, die schon `@MainActor` sind.
- **Sicherheit:** verifiziert.

**A25 · Bekannte offene Befunde, erneut geprüft**
- **Funktionen über 30 Zeilen:** Der Befund besteht weiter. Meine grobe Nachzählung ergibt 52 `func`, ohne `var body` und berechnete Eigenschaften. Die Zahl 96 habe ich mit dieser Zählweise nicht nachgebildet. Die größten Funktionen:

  | Funktion | Ort | Zeilen |
  |---|---|---|
  | `parseItemFromPayload` | `RealtimeEventProcessor.swift:98` | 164 |
  | Parser | `SVGPathParser.swift:27` | 116 |
  | Anmelde-Ansicht | `SignInView.swift:78` | 109 |

- **Zeilen-LWW:** besteht weiter. `migrations/020_scale_and_hardening.sql:155-170` überschreibt bei neuerer HLC alle Spalten auf einmal. Gleichzeitige Änderungen an verschiedenen Feldern gehen deshalb verloren.
- **Fotos als Base64 auf dem Main-Thread:** besteht weiter, siehe A18.

## Gesamteinschätzung

Die unteren Schichten sind sauber von der Oberfläche getrennt. Unter `Core/Sync`, `Core/Storage`, `Repositories` und `Models` importiert keine Datei SwiftUI. `UserLog` steht nur in ViewModels. `FamlistApp` ist ein echter Ort, an dem alle Abhängigkeiten zusammengesetzt werden, und die Repositories haben Protokolle mit Testattrappen. Dadurch bauen 21 Testdateien das ListViewModel ohne Server auf. Das Beobachtungsmuster ist einheitlich (18 `ObservableObject`, 0 `@Observable`), und für lokale Artikel-Änderungen gibt es seit dem Audit nur einen Schreibweg mit HLC. Die Schwäche liegt in der Mitte der Architektur. Das Holen vom Server, die fünf Offline-Warteschlangen und das Abmelden sind über ViewModels, Repositories und die Sync-Schicht verstreut (A1, A2). Zwei große ViewModels halten alles zusammen (A4, A5). Die dringendsten Schritte sind A3 (Schema-Versionierung, sonst droht Datenverlust), danach A2 und A1.

Geändert habe ich nichts. Die einzige Hilfsdatei liegt im Scratchpad: `/private/tmp/claude-501/-Users-robertbogner-GitPrivate-Famlist/ad0df1fc-1ec4-45e6-866d-77d6c419a066/scratchpad/multi.txt`. Sie enthält die Liste der 44 Dateien mit mehreren Typen.

---

## Sync, Offline, Concurrency (S)

# Sync-Audit Famlist (Branch audit-fixes, HEAD 7d54889)

Ich habe keine Datei geändert und nichts committet. In die Datenbank habe ich nichts geschrieben. Ich habe genau eine lesende Abfrage an die Live-Datenbank geschickt: `pg_get_functiondef` für `gc_tombstones` und `items_lww_guard`. Der Grund: `gc_tombstones` steht in keiner Migration im Repo. Die Fehlercodes von PostgREST habe ich in der offiziellen Doku nachgesehen (Context7, PostgREST v14). Das Verhalten des SDK habe ich im Quellcode von supabase-swift unter DerivedData geprüft. Gebaut oder getestet habe ich nichts.

## Befunde (nach Schwere sortiert)

**S1 – hoch – Daten von Konto A gelangen nach einem Sitzungsverlust in Konto B**
- **Belege:**
  - `App/AuthService.swift:109` meldet beim Abmelden alle Geräte ab: `try await client.auth.signOut(scope: .global)`.
  - `AppSessionViewModel+Auth.swift:118–125`: Scheitert das Wiederherstellen der Sitzung, setzt der Code nur `isAuthenticated = false`. `resetLocalState()` läuft nicht.
  - `handleAuthCompletion` prüft nicht, ob die lokalen Daten einem anderen Nutzer gehören.
  - `SupabaseItemCatalogRepository.swift:70–74` setzt den Besitzer auf den aktuell angemeldeten Nutzer: `catalogEntry.ownerPublicId = session.user.id...`.
  - `OfflineItemCatalogRepository.swift:70` zeigt ohne Netz die lokale Kopie: `catch where store.entries != nil`.
  - Einen Listener auf `authStateChanges` gibt es nicht. Die Suche nach `authStateChanges` und `signedOut` ergab keinen Treffer.
- **Ablauf:**
  1. Nutzer A meldet sich auf dem iPhone ab. Der Server beendet damit auch die Sitzung auf dem iPad.
  2. Auf dem iPad liegen noch ungesendete Änderungen von A: Artikel-Warteschlange, Listen- und Katalog-Outbox, Katalog-Kopie.
  3. Beim nächsten Start des iPads schlägt `client.auth.session` dauerhaft fehl. Die App zeigt den Anmeldebildschirm, löscht aber nichts.
  4. Nutzer B meldet sich am iPad an. `fetchAllLists` ruft zuerst `flush()` auf. Die Katalog-Einträge von A landen dann per `save` im Katalog von B.
  5. Ohne Netz sieht B den Katalog von A.
  6. Die Artikel-Aufträge von A gehen mit der Sitzung von B an den Server. Ist B Mitglied derselben Liste, übernimmt der Server sie.
- **Plausible Variante:** Das SDK kann die Sitzung auch während die App läuft entfernen. Dann senden Aufträge ohne Nutzer-Token. Der Server antwortet mit 42501. `SyncErrorClassifier.swift:76` stuft das als dauerhaft ein. Der ganze Stapel wird als „fehlgeschlagen“ markiert.
- **Empfehlung:**
  - Die Nutzer-ID der lokalen Daten speichern.
  - Meldet sich ein anderer Nutzer an oder ist die Sitzung ungültig, vor dem Start `resetLocalState()` aufrufen.
  - `authStateChanges` beobachten.
  - 42501 bzw. „nicht angemeldet“ als vorübergehend behandeln.
- **Sicherheit:** Codepfad verifiziert. Das Verhalten des SDK beim Entfernen der Sitzung ist plausibel, aber nicht geprüft.

**S2 – hoch – Bearbeiten eines Artikels kann dessen Foto bei allen Geräten löschen**
- **Belege:**
  - `ItemFormViewModel.swift:86` liest das Foto beim Öffnen: `if let img = ImageCache.shared.image(fromBase64: item.imageData)`.
  - Zeile 129: `let imageBase64 = selectedImage.flatMap(ProductImageCodec.encode)`.
  - `SyncEngine+LocalChanges.swift:85`: `imageChanged = ... existing?.imageData != item.imageData`. Zeile 87 setzt dann `model.imagePath = nil`.
  - `SyncEngine+Images.swift:21`: `guard let base64 = snapshot.imageData ... else { return nil }`.
  - `SupabaseItemsRepository+CRUD.swift:54`: `if includeImage { try c.encode(item.imagePath, ...) }`. Dabei geht explizit `null` an den Server.
  - Migration 020, Zeilen 164–165: Der Server übernimmt `image_path = NULL`.
- **Ablauf:**
  1. Gerät B fügt „Milch“ ein Foto hinzu.
  2. Gerät A erhält die Änderung. Der neue Pfad setzt `imageData = nil`, und der Prefetcher lädt das Foto im Hintergrund.
  3. Der Nutzer öffnet auf A das Bearbeiten-Fenster, bevor der Download fertig ist. Das Formular hat deshalb kein Foto.
  4. Der Download endet, und die Zeile in SwiftData hat jetzt Bilddaten.
  5. Der Nutzer ändert die Menge und speichert. Formular (nil) und Zeile (Daten) unterscheiden sich, also gilt das Foto als geändert.
  6. Die App sendet `image_path: null`. Das Foto verschwindet auf allen Geräten.
- **Empfehlung:**
  - Das Foto nur dann mitsenden, wenn der Nutzer es im Formular wirklich geändert hat. Dafür einen Merker `imageEdited` einführen.
  - Grundsätzlich die aktuelle SwiftData-Zeile als Basis nehmen und nur geänderte Felder übernehmen.
- **Sicherheit:** Codepfad verifiziert. Das Zeitfenster ist plausibel (einige Sekunden beim Download).

**S3 – mittel – Jedes Speichern im Bearbeiten-Fenster lädt das Foto neu hoch und verschlechtert es**
- **Belege:**
  - `ItemFormViewModel.swift:129` kodiert das Foto bei jedem Speichern neu.
  - `ProductImageCodec.swift:38–51`: Das Bild wird neu gezeichnet und mit `jpegData(compressionQuality: 0.72)` gespeichert.
  - Zeile 57 bildet den Dateinamen aus dem SHA-256 des Inhalts.
- **Ablauf:**
  1. Der Nutzer ändert nur den Preis und speichert.
  2. Das Foto wird aus Base64 dekodiert und erneut als JPEG kodiert. Die Bytes sind danach sehr wahrscheinlich anders.
  3. Deshalb gilt das Foto als geändert (`imageChanged = true`).
  4. Die App lädt eine neue Datei unter neuem Pfad hoch. Die alte Datei bleibt im Storage liegen.
  5. Die Bildqualität sinkt bei jedem Speichern etwas.
- **Empfehlung:** Die ursprünglichen Base64-Daten behalten, solange der Nutzer kein neues Foto wählt.
- **Sicherheit:** Code verifiziert. Dass die JPEG-Bytes beim Neukodieren abweichen, ist plausibel (sehr wahrscheinlich).

**S4 – mittel – Gelöschte Artikel kommen nach mehr als 30 Tagen offline zurück**
- **Belege:**
  - Live-Funktion `gc_tombstones`: `DELETE FROM items WHERE tombstone = true AND updated_at < now() - interval '30 days'`.
  - `items_lww_guard` (Migration 015, Zeilen 49–57) vergleicht die HLC nur bei `UPDATE`. Ein `INSERT` mit alter HLC geht immer durch.
- **Ablauf:**
  1. Gerät X ist 35 Tage offline und hat eine ungesendete Änderung an „Brot“.
  2. Gerät Y löscht „Brot“ am ersten Tag.
  3. Am 31. Tag entfernt der Server die Löschmarkierung endgültig.
  4. X kommt online und sendet seine Änderung. Weil die Zeile fehlt, legt der Server sie neu an. „Brot“ erscheint bei allen wieder.
  5. Der Abgleich in `ListViewModel+Reconcile` hilft hier nicht. Er entfernt nur Artikel mit Status `.synced`, und diese Änderung ist noch nicht gesendet.
- **Empfehlung:** Im Guard ein `INSERT` ablehnen (Status „stale“), wenn `hlc_timestamp` älter ist als die Aufbewahrungsfrist der Löschmarkierungen. Alternativ eine Tabelle mit gelöschten IDs führen.
- **Sicherheit:** verifiziert.

**S5 – mittel – Eine falsch vorgehende Uhr macht Artikel dauerhaft unsendbar**
- **Belege:**
  - `SyncEngine+LocalChanges.swift:83`: `existing.map { hlcGenerator.receive($0.hlc) }`.
  - `HybridLogicalClock.swift:177`: `max(physicalTime, max(lastHLC.timestamp, remoteHLC.timestamp))`.
  - Migration 015, Zeilen 46–47: Der Server lehnt Zeitstempel ab, die mehr als einen Tag in der Zukunft liegen.
  - Die Korrektur beim Start in Zeile 124 betrifft nur den Generator, nicht die HLC der gespeicherten Artikel.
- **Ablauf:**
  1. Die Geräteuhr steht versehentlich ein Jahr vor. Der Nutzer ändert „Milch“.
  2. Die lokale Zeile bekommt einen Zeitstempel ein Jahr in der Zukunft. Der Server antwortet „invalid“, und der Artikel wird als „fehlgeschlagen“ markiert.
  3. Der Nutzer stellt die Uhr richtig.
  4. „Erneut versuchen“ sendet denselben Auftrag noch einmal (Zeilen 123–134) und scheitert wieder.
  5. Auch jede neue Änderung übernimmt über `receive` den Zukunfts-Zeitstempel der Zeile.
  6. Der Artikel erreicht den Server erst, wenn die echte Zeit diesen Stand fast erreicht hat.
- **Empfehlung:**
  - Liegt die HLC einer lokalen Zeile mehr als einen Tag in der Zukunft, bei `receive` die physische Zeit verwenden.
  - Bei der Antwort „invalid“ mit „too far in the future“ den Auftrag mit neuer HLC neu einreihen.
- **Sicherheit:** verifiziert.

**S6 – mittel – Kurze Server-Ausfälle markieren ganze Stapel als „fehlgeschlagen“**
- **Belege:**
  - `SyncErrorClassifier.swift:72`: Nur Codes mit dem Präfix `PGRST3` gelten als vorübergehend.
  - Zeile 76: Alle übrigen Codes werden als dauerhaft eingestuft (`return .permanent`).
  - `SyncEngine.swift:209, 242–244`: Ein dauerhafter Fehler setzt jeden Auftrag im Stapel auf „fehlgeschlagen“.
  - Laut PostgREST-Doku bedeuten PGRST000–002 „503, keine Datenbankverbindung“ und PGRST003 „504, Wartezeit auf eine Pool-Verbindung überschritten“.
  - Das SDK dekodiert den Fehler-Body als `PostgrestError` (`PostgrestBuilder.swift:130`).
- **Ablauf:**
  1. Unter Last meldet PostgREST PGRST003.
  2. Bis zu 100 Aufträge werden dauerhaft „fehlgeschlagen“.
  3. Der Nutzer muss jeden Artikel einzeln erneut versuchen.
- **Empfehlung:** `PGRST0` als vorübergehend behandeln. Besser zusätzlich den HTTP-Status 503/504 auswerten.
- **Sicherheit:** verifiziert.

**S7 – mittel – Zusammenfassen in der Warteschlange verliert eine Foto-Änderung**
- **Belege:**
  - `OperationQueue.swift:52–55`: `for existing in fetch(itemId:) where !inFlight.contains(existing.id) { context.delete(existing) }`.
  - Der neue Auftrag setzt `includesImage` nur für seine eigene Änderung (`LocalChanges.swift:85`).
- **Ablauf:**
  1. Der Nutzer entfernt offline das Foto von „Käse“. Der erste Auftrag hat `includesImage = true` und `image_path = null`.
  2. Danach hakt er „Käse“ ab. Der zweite Auftrag hat `includesImage = false` und ersetzt den ersten.
  3. Der Server behält das Foto.
  4. Die nächste Änderung eines anderen Geräts bringt den Pfad zurück, und das Foto erscheint wieder.
  5. Ein neu hinzugefügtes Foto wird später durch `migrateLegacyImages` nachgeholt. Das Entfernen eines Fotos geht dagegen verloren.
- **Empfehlung:** Beim Ersetzen die Merker verknüpfen: `includesImage = alt || neu`.
- **Sicherheit:** verifiziert.

**S8 – mittel – Die Katalog-Warteschlange verwirft Aufträge bei vorübergehenden Fehlern**
- **Belege:**
  - `OfflineItemCatalogRepository.swift:146`: Nur `catch let error as URLError` gilt als „offline“.
  - Zeile 153: `if pending.failures + 1 >= Self.maxFailures { store.removeFirst() }`.
  - `search` (Zeile 105) ruft bei jedem Aufruf `flush()` auf.
- **Ablauf:**
  1. Der Server antwortet kurz mit 5xx, oder das Token ist abgelaufen (401).
  2. Der Nutzer tippt fünf Buchstaben in die Suche. Jeder Tastendruck löst ein `flush()` aus und zählt einen Fehlversuch.
  3. Nach dem fünften Fehlversuch löscht die App den Katalog-Eintrag still.
- **Empfehlung:** Wie bei den Listen `SyncErrorClassifier` verwenden. Vorübergehende Fehler nicht zählen.
- **Sicherheit:** Code verifiziert. Wie oft der Fall eintritt, ist plausibel.

**S9 – mittel – Die App prüft die Server-Grenzen nicht; offline angelegte Listen können verloren gehen**
- **Belege:**
  - Migration 020, Zeilen 90–100: Name höchstens 200 Zeichen, Menge (`measure`) höchstens 30, Beschreibung höchstens 500, Preis unter 1.000.000.
  - Migration 018: Listentitel 1–100 Zeichen.
  - `Validation.swift` prüft keine Höchstlänge. Die Suche ergab keine weiteren Grenzen in der App.
  - `OfflineListsRepository.swift:179–182`: Aufträge mit dauerhaftem Fehler werden verworfen (`store.removeFirst()`).
- **Ablauf 1:** Ein Import aus der Zwischenablage erzeugt einen Artikel mit 250 Zeichen im Namen. Der Server antwortet „invalid“. Der Artikel bleibt für immer „fehlgeschlagen“, und „Erneut versuchen“ hilft nicht.
- **Ablauf 2:**
  1. Der Nutzer legt offline eine Liste mit 120 Zeichen im Titel an und fügt Artikel hinzu.
  2. Das Anlegen scheitert dauerhaft (23514), und der Auftrag wird verworfen.
  3. `isListReady` meldet jetzt `true`. Die Artikel gehen an den Server und scheitern mit einem Fremdschlüssel-Fehler (23503).
  4. Die Liste verschwindet aus der Anzeige. Die Artikel bleiben unsichtbar in SwiftData.
- **Empfehlung:** Die Grenzen in der App durchsetzen (kürzen oder Fehler anzeigen). Scheitert das Anlegen einer Liste dauerhaft, den Nutzer informieren.
- **Sicherheit:** Code verifiziert. Dass die App keine Grenzen hat, stützt sich auf die Suche im Code.

**S10 – niedrig – Der Server meldet vorübergehende Datenbankfehler als „invalid“**
- **Beleg:** Migration 020, Zeilen 186–188: `WHEN OTHERS THEN ... status := 'invalid'`.
- **Ablauf:**
  1. Zwei Geräte haken gleichzeitig viele Artikel in unterschiedlicher Reihenfolge ab.
  2. Postgres erkennt eine Verklemmung (Deadlock, 40P01). Der Fehler wird im Unterblock abgefangen und als „invalid“ gemeldet.
  3. Die App markiert den Auftrag dauerhaft als fehlgeschlagen.
- **Empfehlung:** 40P01, 40001 und 55P03 als eigenen Status „retry“ melden.
- **Sicherheit:** plausibel.

**S11 – niedrig – Die Listen-Warteschlange wird nach einem Serverfehler nicht erneut versucht**
- **Beleg:** `OfflineListsRepository.swift:175–177`: Bei einem vorübergehenden Fehler bricht `drain` mit `break` ab. Einen Zeitgeber für einen neuen Versuch gibt es nicht.
- **Ablauf:**
  1. Der Nutzer legt online eine Liste an, und der Server antwortet mit 503.
  2. Neue Versuche starten nur beim Wechsel von offline zu online, bei einer weiteren Listen-Aktion, beim Öffnen von „Meine Listen“ oder beim App-Start.
  3. Bis dahin stellt die SyncEngine die Artikel der Liste alle 5 s zurück.
- **Empfehlung:** Nach dem Fehler einen neuen Versuch mit wachsender Wartezeit einplanen.
- **Sicherheit:** verifiziert.

**S12 – niedrig – Schreibvorgänge basieren auf der Anzeige-Kopie statt auf der aktuellen Zeile**
- **Belege:**
  - `ListViewModel+ItemCRUD.swift:223`: `var updatedItem = items[index]`.
  - `SwiftDataItemStore.swift:114`: `entity.assignContent(from: model)`.
  - `ListViewModel+RealtimeSync.swift:64`: Während einer Massenaktion werden Realtime-Stände verworfen (`guard !self.isBulkMutationActive else { return }`).
  - `deleteInOneBatch` hält diesen Zustand bis zum Ende des Sendens aktiv (`BulkActions.swift:206–210`).
- **Ablauf:**
  1. Der Nutzer löscht erledigte Artikel, und das Senden dauert einige Sekunden.
  2. In dieser Zeit ändert ein anderes Gerät die Menge von „Eier“. SwiftData übernimmt die Änderung, die Anzeige nicht.
  3. Der Nutzer hakt „Eier“ ab. Die App schreibt die alte Menge mit neuerer HLC.
  4. Die Änderung des anderen Geräts geht verloren, obwohl sie zeitlich vorher kam.
- **Empfehlung:** In `write()` die aktuelle SwiftData-Zeile laden und nur die geänderten Felder übernehmen.
- **Sicherheit:** verifiziert. Das Zeitfenster ist kurz.

**S13 – niedrig – Der 25-Tage-Abgleich entfernt gerade eingetroffene Artikel**
- **Beleg:** `ListViewModel+Reconcile.swift:37–53`: Zwischen `fetchItemIds` (mit `await`) und `removeVanishedItems` können neue Artikel ankommen.
- **Ablauf:**
  1. Während die ID-Liste lädt, fügt jemand „Butter“ hinzu. „Butter“ kommt per Realtime mit Status `.synced` an.
  2. Die ID-Liste enthält „Butter“ noch nicht. Der Abgleich entfernt „Butter“ deshalb lokal.
  3. Erst der nächste Delta-Abgleich holt „Butter“ zurück.
- **Empfehlung:** Nur Zeilen entfernen, deren `updatedAt` älter ist als der Beginn der Abfrage.
- **Sicherheit:** verifiziert. Tritt nur alle 25 Tage auf.

**S14 – niedrig – `observe()` der HLC wird nie aufgerufen**
- **Beleg:** `HybridLogicalClock.swift:132` definiert `observe`. Die Suche fand keinen Aufruf im App-Code. Nur `receive` für die lokale Zeile und `tick` werden verwendet.
- **Folge:**
  - Neue Artikel ohne lokale Zeile bekommen eine HLC, die nur auf der eigenen Uhr beruht.
  - Beispiel: „Milch“ wurde auf einem Gerät mit vorgehender Uhr gelöscht, die Löschmarkierung ist lokal aber noch nicht da. Dann wird das Neu-Anlegen als „stale“ verworfen, und der Artikel verschwindet wieder.
  - Der Dateikopf behauptet, `observe` werde genutzt.
- **Empfehlung:** `observe` bei Realtime-, Delta- und RPC-Zeilen aufrufen.
- **Sicherheit:** Die fehlende Nutzung ist verifiziert, das Szenario plausibel.

**S15 – niedrig – Beim Löschen einer Liste verwirft die App lokale Daten vor der Bestätigung des Servers**
- **Beleg:** `ListViewModel+ListManagement.swift:164–169`: `try await repo.deleteList(...)` kehrt beim Offline-Repository sofort zurück, danach folgt `forgetLocalData`. Der Kommentar in Zeile 149 sagt das Gegenteil.
- **Folge:** Scheitert das Löschen später dauerhaft (z. B. mit 42501), kehrt die Liste zurück. Ungesendete Artikel-Änderungen dieser Liste sind dann weg.
- **Sicherheit:** verifiziert.

**S16 – niedrig – Realtime-Ereignisse nach dem Abmelden schreiben wieder in SwiftData**
- **Belege:**
  - `ListViewModel.swift:255 ff.` löscht alles synchron.
  - Der Kanal wird erst später über `onTermination` und einen Task abgebaut (`SupabaseItemsRepository.swift:108–116`).
  - `processUpsert` prüft weder Sitzung noch beobachtete Liste.
- **Folge:** Ein Ereignis, das in dieser Lücke verarbeitet wird, legt einen Artikel des alten Kontos wieder lokal an. Er ist für das nächste Konto meist unsichtbar.
- **Empfehlung:** Den Kanal im Abmeldeweg synchron beenden oder in `handleRealtimeEvent` die aktive Liste prüfen.
- **Sicherheit:** plausibel.

## Bekannte offene Punkte

| Punkt | Stand |
|---|---|
| Zeilen-LWW verliert parallele Änderungen verschiedener Felder | Trifft weiter zu. `UpsertRow` sendet alle Felder, `upsert_items_lww` setzt alle Spalten. S12 verschärft das noch. |
| Entfernte Mitglieder empfangen Realtime bis zur Neuverbindung | Trifft serverseitig weiter zu. Die Policy `list_topic_read` greift nur beim Beitritt zum Kanal. Die App selbst reagiert auf `member_removed`. |
| Fotos als Base64 in SwiftData auf dem Main-Thread | Trifft weiter zu (`ItemImagePrefetcher.swift:58`, `ItemEntity.imageData`). |

## Gesamteinschätzung

Der Sync-Kern ist sauber gebaut. Es gibt einen einzigen Schreibweg mit HLC, pro Artikel ist höchstens ein Auftrag unterwegs, und ein erneut gesendeter Auftrag mit gleicher HLC wird als „stale“ quittiert. `SentOperation` schützt davor, gelöschte Objekte nach einem `await` zu lesen. Nach jeder Anmeldung am Kanal läuft ein Delta-Abgleich mit 5 s Überlappung und stabilem Cursor.

Die Escape-Hatches sind begründet. Betroffen sind `nonisolated(unsafe)` mit `NSLock` in AppFont, `@unchecked Sendable` in ImageCache und ReceiptCamera, `assumeIsolated` bei der Apple-Anmeldung und `Task.detached` bei der Belegerkennung. Einen falschen Actor für den ModelContext habe ich nicht gefunden. Die Wiederverwendung von Kanälen stimmt mit dem SDK überein (`RealtimeClientV2.channel` liefert den vorhandenen Kanal zurück).

Die größten Risiken liegen an den Rändern des Kerns:
- Kontowechsel ohne Bereinigung (S1).
- Foto-Logik, die auf Kopien aus der Anzeige basiert (S2, S3, S7).
- Fehlerklassen, die vorübergehende Fehler als dauerhaft behandeln (S6, S8, S10).
- Fehlender Schutz gegen Wiederanlegen nach dem endgültigen Löschen der Löschmarkierungen (S4).

Zuerst würde ich S1, S2 und S6 beheben. Alle drei lassen sich mit kleinen, gezielten Änderungen lösen.

---

## Clean Code & Duplikate (C)

# Clean-Code-Audit Famlist (Branch audit-fixes, HEAD 7d54889)

Ich habe nur gelesen und keine Datei geändert. Gemessen habe ich 333 Swift-Dateien in `Famlist/` ohne `FamlistTests`, zusammen 33.516 Zeilen. Die Messskripte liegen im Scratchpad unter `/private/tmp/claude-501/-Users-robertbogner-GitPrivate-Famlist/ad0df1fc-1ec4-45e6-866d-77d6c419a066/scratchpad/`: `funclen.py`, `dup.py`, `types.py`, `deadfunc.py` und `idioms.py`.

## Kennzahlen

| Metrik | Wert | Wie gemessen |
|---|---|---|
| Gemessene Funktionen (func, init, deinit, `var body`) | 1.301 | Python; Klammern zählen, nachdem Strings und Kommentare entfernt sind |
| Funktionen über 30 / 50 / 80 Zeilen | **98** / 31 / 10 | wie oben; die bekannte Zahl ~96 ist damit bestätigt |
| Dasselbe mit allen `some View`-Eigenschaften | 104 / 31 / 10 | wie oben, Muster erweitert |
| Davon `var body` über 30 Zeilen | 40 | wie oben |
| Dateien über 300 Zeilen | 1 (`SyncEngine.swift` mit 304) | `wc -l` |
| Dateien mit mehr als einem Top-Level-Typ | 44, davon 23 mit nicht-privaten Zusatztypen | Regex über Typdeklarationen |
| Doppelte Codeblöcke (8 normalisierte Zeilen, ≥ 200 Zeichen) | 22 Dateigruppen, die größte hat 23 gleiche Fenster | `dup.py` |
| Funktionen ohne jeden Aufruf | 38 gefunden, davon 31 echt tot (21 davon `UserLog.*`) | Name per grep in App und Tests gesucht; Delegate-Methoden von Hand aussortiert |
| Funktionen, die nur Tests aufrufen | 3 | wie oben |
| `// TODO`, `FIXME`, `HACK` | **0** | grep |
| Auskommentierte Codeblöcke (≥ 2 Zeilen) | **0** | Regex auf Kommentare, die wie Code aussehen |
| `try!` / `as!` / `fatalError` | 0 / 1 / 1 | Python, ohne Kommentare und Strings |
| Force-Unwraps `x!` | 6 | wie oben |
| `print(` | 5, alle in `Logger.swift` oder `UserLogger.swift` | wie oben |
| `DispatchQueue` / `AnyView` | 3 (von NWPathMonitor und AVCapture verlangt) / 0 | wie oben |
| `Task.sleep(nanoseconds:)` mit roher Zahl | 23 | grep |
| `try?` (Fehler wird still verworfen) | 124 | grep |
| SF Symbols (`Image(systemName:`, `systemImage:`) | **0** | Python |
| `.font(.system(…))` / `.font(.body)` o. Ä. | 2 / 0 | Python |
| Hex-Farben außerhalb von Theme-, Token- und Design-Dateien | 103 in 48 Dateien (57 im Produktivcode, 46 in `#Preview`) | Python |
| `UserLog`-Aufrufe außerhalb von ViewModels | **0** | Python, nach Datei gruppiert |
| Funktionen mit mehr als 5 Parametern | 16 (die größte hat 23) | Python |
| Tiefe Verschachtelung | Logik-Dateien: 0 Stellen mit mehr als 4 Kontrollebenen. Views: 682 Zeilen in 108 Dateien mit ≥ 7 Einrückungsebenen, maximal 15 | Python |
| String Catalog | 177 Schlüssel; Quellsprache `en`; 302 UI-Literale, davon nur 27 im Katalog; 74 von 129 Punkt-Schlüsseln werden nirgends benutzt | Python über `Localizable.xcstrings` |
| Kommentarsprache | 2.283 rein deutsche und 1.453 rein englische Kommentarzeilen; 41 Dateien gemischt; 0 deutsche Bezeichner | Python, Wortlisten |
| Zeilen mit Kommentar hinter dem Code | 620 | Python |
| Zahlen-Literale (ohne 0, 1, 2) | 3.911 in View- und Design-Dateien, 224 in Logik-Dateien | Python |

## Befunde

**C1 – hoch – Die Listen-Oberfläche existiert zweimal: einmal „echt“, einmal als Design-Kopie**
- **Wo:** `Famlist/Shared/Components/Hybrid/Design/` mit 8 Dateien und 783 Zeilen.
- **Beleg:** Das Duplikat-Skript findet diese Paare:
  - `ProgressHero.swift:52` und `DesignProgressHero.swift:35` (23 gleiche Fenster)
  - `ListEmptyState.swift:35` und `DesignListEmptyState.swift:32` (7)
  - `UndoActionButton.swift:28` und `DesignItemRow.swift:110` (5)
  - `ListFilterTabs.swift:50` und `DesignListTabs.swift:41` (4)
  - `ListSectionHeader.swift:64` und `DesignSectionHeader.swift:53` (2)
- **Wo die Kopie läuft:** `DesignListScreen` ist ein statischer Hintergrund mit Beispieldaten. Er wird trotzdem im `body` von 9 Produktiv-Sheets gebaut, zum Beispiel `ReceiptReviewSheet.swift:42` und `SettingsSheet.swift:47`. In der App blendet `EKKSheetStage.swift:30` ihn über `hybridHosted` wieder aus.
- **Folge:** Jede Designänderung an der Liste muss man zweimal machen. Außerdem zeigen die Vorschauen eine andere Liste als die App.
- **Empfehlung:** Den Hintergrund entweder hinter `#if DEBUG` legen oder aus den echten Komponenten mit Beispieldaten bauen. Das berührt die Regel „Referenz-Views übernehmen“ in CLAUDE.md. Deshalb musst du das entscheiden.
- **Sicherheit:** verifiziert.

**C2 – hoch – Die Realtime-Nachrichten werden umständlich und ein drittes Mal gemappt**
- **Wo:** `Core/Sync/RealtimeEventProcessor.swift:98`, `parseItemFromPayload`, 164 Zeilen. Das ist die längste Funktion im Projekt.
- **Beleg:** Die Funktion liest Werte über `String(describing:)` und entfernt dabei den Text `"AnyJSON."`. `SupabaseRealtimeManager.swift:180` (`bridge`) wandelt die Daten aber schon per `JSONSerialization` in normale Swift-Typen um. Die Zweige für AnyJSON sind daher toter Schutzcode.
- **Dreifaches Mapping:** Dieselbe Datenbankzeile wird zusätzlich in `SupabaseItemRow.swift:68` (`toItemModel`) und in `ItemEntity+Mapping` gemappt. Die mitberechneten `CRDTMetadata` verwirft der Aufrufer (`let (item, _)` in Zeile 61).
- **Möglicher Fehler beim Datum:** Der Datums-Formatter in Zeile 36 hat die Standardoptionen, also ohne Sekundenbruchteile. `SupabaseItemRow.swift:69` versucht dagegen zuerst das Format mit Bruchteilen. Die Spalte `created_at` ist `TIMESTAMPTZ DEFAULT now()` und hat damit Mikrosekunden. Wahrscheinlich liefert Realtime deshalb `createdAt = nil`. Ein neuer Artikel bekäme dann die Gerätezeit (`ItemEntity+Mapping.swift:142`).
- **Empfehlung:** Den Datensatz in `SupabaseItemRow` dekodieren und `toItemModel()` wiederverwenden.
- **Sicherheit:** Der überflüssige Code ist verifiziert. Den Datumsfehler halte ich für plausibel; ich habe keine Live-Nachricht geprüft.

**C3 – mittel – 98 Funktionen sind länger als 30 Zeilen**
Die längsten 15 Funktionen:

| Zeilen | Datei:Zeile |
|---|---|
| 164 | `RealtimeEventProcessor.swift:98` |
| 121 | `FamlistApp.swift:42` (init) |
| 119 | `EditProfileSheet.swift:37` (body) |
| 116 | `SVGPathParser.swift:27` |
| 109 | `SignInView.swift:78` |
| 106 | `PriceHistorySheet.swift:34` |
| 103 | `ProfileSetupView.swift:41` |
| 97 | `ImportMergeService.swift:72` |
| 86 | `ShoppingListView+Sheets.swift:95` |
| 83 | `AcceptInviteView.swift:30` |
| 78 | `ListViewModel+ItemCRUD.swift:97` (`updateItem`) |
| 76 | `ListOptionsMenu.swift:38` |
| 76 | `BarcodeScanSheet.swift:49` |
| 75 | `ManageCategoriesSheet.swift:38` |
| 74 | `EditCategorySheet.swift:43` |

- **Folge:** 40 der 98 Funktionen sind View-Bodies. Solche Views sind schwer zu überblicken und zu testen.
- **Empfehlung:** Unteransichten auslagern. Bei `FamlistApp.init` hilft eine eigene Factory für die Abhängigkeiten.
- **Sicherheit:** verifiziert.

**C4 – mittel – `ListViewModel` ist ein zu großes Objekt, das auf viele Dateien verteilt ist**
- **Beleg:** Das ViewModel steckt in 20 Dateien mit zusammen 2.619 Zeilen und hat 21 `@Published`-Eigenschaften. Es hat 7 nachträgliche `configure(…)`-Setter; die App ruft sie in `FamlistApp.swift:105-115` nacheinander auf.
- **Folge:** Die Regel „Datei ≤ 300 Zeilen“ ist nur formal erfüllt. Die Setter bedeuten eine Initialisierung in zwei Schritten: Vergisst man einen `configure`-Aufruf, bleibt eine Abhängigkeit `nil`, und das fällt erst zur Laufzeit auf.
- **Empfehlung:** Abhängigkeiten im Initialisierer übergeben. Teilbereiche wie Katalog, Belege und Bulk-Aktionen in eigene ViewModels oder Dienste auslagern.
- **Sicherheit:** verifiziert.

**C5 – mittel – Ganze Typen sind tot**
- `DS` in `Core/DesignSystem/DesignSystem.swift:29`: `DS.` kommt nirgends im Code vor.
- `ColorTheme` und `Color.theme` in `Core/DesignSystem/Color.swift:28/32`: 0 Aufrufe. Dazu gehören 8 Farbsätze unter `ThemeColors`. Davon wird nur `AccentColor` benutzt, und zwar über die Build-Einstellung.
- `AuthViewModel` und `AuthMode` in `Features/Authentication/ViewModels/AuthViewModel.swift`: Sie werden nur in Tests benutzt. Der Ordner `Features/Authentication/Models` ist leer. Seit `SignInView` gibt es keinen Aufrufer mehr (`SignInView.swift:20`: „Ersetzt AuthView“).
- `SyncMonitor`: Die App legt ihn an und übergibt ihn als `environmentObject` (`FamlistApp.swift:191`). Keine View liest ihn per `@EnvironmentObject`. Seine Messwerte wie `averageLatency` („for compatibility with indicator“, Zeile 47) liest niemand.
- **Folge:** Toter Code verwirrt beim Lesen und wird unnötig mitgepflegt.
- **Empfehlung:** Löschen. Beim `SyncMonitor` entscheiden, ob er eine Anzeige bekommt oder wegfällt.
- **Sicherheit:** verifiziert.

**C6 – mittel – 31 Funktionen werden nie aufgerufen**
- **Beispiele:**
  - `ListViewModel+Duplicate.swift:28` `duplicateActiveList`
  - `ListViewModel+Persistence.swift:62` `retryLoadDefaultList`
  - `OperationQueue.swift:62` `dequeue` und Zeile 200 `clearFailed`
  - `SyncOperation.swift:134` `decodeCRDTMetadata`
  - `ItemModel.swift:118` `compare`
  - `Validation.swift:59` `canPersist`
  - `Utils.swift:32` `imageToBase64` (als deprecated markiert) und Zeile 42 `chunked`
  - `UIImage+Utils.swift:55` und `:69`
- **UserLog:** 21 Einträge sind unbenutzt, zum Beispiel `UserLog+Sync.swift:52` (`offlineMode`) und `:56` (`onlineMode`) sowie `UserLog+UI.swift:20` (`appLaunched`).
- **Nur von Tests benutzt:** `OperationQueue.peek`, `SyncMonitor.recordConflict`, `CategoryStore.waitForWrites`.
- **Tote Eigenschaft:** `ListViewModel.swift:48` `selectedItem` wird nur auf `nil` gesetzt.
- **Folge:** Diese Funktionen sehen nach nutzbarer Schnittstelle aus, werden aber nie ausgeführt.
- **Empfehlung:** Löschen.
- **Sicherheit:** verifiziert per grep. Aufrufe über Reflection sind in Swift ohne `@objc` ausgeschlossen.

**C7 – niedrig – Drei Bild-Assets werden nicht benutzt**
- **Beleg:** `famlistLoginBackground` (1,5 MB), `famlistLogo` (308 KB) und `defaultImage` (28 KB) haben 0 Verweise in Swift, `Info.plist` und `pbxproj`.
- **Folge:** Die App ist dadurch etwa 1,8 MB größer als nötig.
- **Empfehlung:** Die drei Assets löschen.
- **Sicherheit:** verifiziert.

**C8 – mittel – Zwei lokale Speicher-Klassen sind fast identisch**
- **Beleg:** `Repositories/Offline/CatalogLocalStore.swift` (93 Zeilen) und `ListLocalStore.swift` (90 Zeilen). `diff` zeigt nur 43 abweichende Zeilen, und die unterscheiden sich fast nur in Typnamen.
- **Folge:** Ein Fehler in der Speicher-Logik muss in beiden Dateien behoben werden.
- **Empfehlung:** Eine generische Klasse `LocalStore<Entry, Operation>` bauen.
- **Sicherheit:** verifiziert.

**C9 – mittel – Die Preisformatierung steht fünfmal im Code**
- **Beleg:** `.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))` steht in:
  - `PriceDisplaySetting.swift:31` (dort gibt es bereits die Hilfsfunktion `euro`)
  - `PriceHistoryViewModel.swift:71`
  - `ReceiptReviewSheet.swift:128` und `:153`
  - `ShoppingDoneView.swift:93`
- **Abweichung:** `SheetPriceField.swift:41` nimmt stattdessen `Locale.current.currencySymbol`. Auf einem US-Gerät stünde dort „$“, sonst überall „€“.
- **Empfehlung:** Überall `PriceDisplaySetting.euro` benutzen.
- **Sicherheit:** Der Code ist verifiziert. Das „$“ auf US-Geräten halte ich für plausibel.

**C10 – mittel – Der Anzeigename aus Marke und Name ist sechsmal nachgebaut**
- **Beleg:** `[brand, name].compactMap…joined` mit dem Ersatzwort „Artikel“ steht in:
  - `ListViewModel+ItemCRUD.swift:41`, `:120`, `:197`, `:229`
  - `PriceHistorySheet.swift:52`
- Dabei gibt es in `ListViewModel+ItemStatus.swift:66` schon eine private Funktion `displayName(of:)` dafür.
- **Empfehlung:** Eine Eigenschaft `ItemModel.displayName` anlegen und überall benutzen.
- **Sicherheit:** verifiziert.

**C11 – mittel – Datums-Formatter werden an vier Stellen neu gebaut, teils bei jedem Aufruf**
- **Beleg:**
  - `SupabaseItemRow.swift:69-71` erzeugt bei jeder Zeile zwei neue `ISO8601DateFormatter`.
  - `ListViewModel+Persistence.swift:122` erzeugt bei jedem Aufruf einen neuen.
  - `PriceHistoryViewModel.swift:76` und `:84` erzeugen bei jedem Aufruf einen neuen `DateFormatter`.
  - Gemeinsam genutzte Formatter mit unterschiedlichen Optionen gibt es zusätzlich in `PaginationCursor.swift:47` und `RealtimeEventProcessor.swift:36`.
- **Folge:** Formatter anzulegen ist teuer; im Seitenladen passiert das für jede Zeile. Die Optionen sind uneinheitlich, das hängt mit dem Datumsproblem aus C2 zusammen.
- **Empfehlung:** Ein zentraler Parser für Supabase-Zeitstempel.
- **Sicherheit:** verifiziert.

**C12 – mittel – Zeiten und Grenzwerte stehen als rohe Zahlen im Code**
- **Wartezeiten:** 23 Aufrufe `Task.sleep(nanoseconds: 2_000_000_000)` o. Ä.
  - 2 Sekunden Toast-Dauer an 5 Stellen, zum Beispiel `AppSessionViewModel.swift:152`, `ListViewModel+Feedback.swift:28`, `ShoppingListView+Overlays.swift:241`.
  - 4 Sekunden an 3 Stellen: `ShareMembersSheet.swift:67`, `AcceptInviteView.swift:128`, `SignInView.swift:223`.
  - 350 ms Debounce (Wartezeit nach dem letzten Tastendruck) an 4 Stellen: `EditProfileSheet.swift:143`, `ProfileSetupView.swift:131`, `SheetTextField.swift:54`, `ListAccountFocusedField.swift:55`. Die Suche wartet dagegen 300 ms (`ItemSearchViewModel.swift:90`).
- **Grenzwerte:**
  - Maximal 5 Vorschläge an 4 Stellen: `SupabaseItemCatalogRepository.swift:61`, `OfflineItemCatalogRepository.swift:119`, `ItemCatalogRepository.swift:181`, `GlobalProductCatalogRepository.swift:157`.
  - Höchstmenge 999 doppelt: `Validation.swift:44` und `SheetQuantityStepper.swift:27`.
  - Die Sync-Schleife fragt alle 5 Sekunden ab: `SyncEngine.swift:265`.
- **Folge:** Ändert man einen Wert, muss man jede Stelle einzeln finden.
- **Empfehlung:** Benannte Konstanten anlegen und `Task.sleep(for: .seconds(…))` benutzen.
- **Sicherheit:** verifiziert.

**C13 – mittel – Der Profil-Block steht in zwei Views gleich**
- **Beleg:** `EditProfileSheet.swift:141-153` und `ProfileSetupView.swift:129-141` enthalten identisch:
  - die Prüfung des Benutzernamens mit 350 ms Wartezeit
  - das Hochladen des Profilbilds per `onChange(of: photo)`
- **Empfehlung:** Einen gemeinsamen ViewModifier oder ein kleines ViewModel daraus machen.
- **Sicherheit:** verifiziert.

**C14 – hoch – Die Lokalisierung ist uneinheitlich und größtenteils nicht umgesetzt**
- **Sprache:** `Localizable.xcstrings` hat `sourceLanguage: en`, und im Projekt ist `developmentRegion = en`. Die Texte in der Oberfläche stehen aber als deutsche Literale im Code.
- **Abdeckung:** Von 302 UI-Literalen in `Text`, `Button`, `accessibilityLabel`, `title:` usw. stehen nur 27 im Katalog.
- **Zwei Schlüssel-Stile:** Punkt-Schlüssel wie `unit.kg` neben deutschen Textschlüsseln. Von 129 Punkt-Schlüsseln sind 74 unbenutzt, zum Beispiel `auth.*` und `addItem.title`.
- **Mehrzahl von Hand:** „Artikel“ oder „Artikeln“ wird im Code gewählt (`ProgressHero.swift:49`, `ShoppingDoneView.swift:198`), statt Plural-Varianten im Katalog zu nutzen.
- **Fehlertexte:** 15 `errorMessage = "…"` sind feste Literale, 5 nutzen `String(localized:)`, und 6 Stellen nutzen `UserFacingError`.
- **Folge:** Eine englische Version ist nur mit Code-Änderungen möglich. Viele Komponenten nehmen Texte als `String` entgegen, und solche Parameter werden nicht übersetzt.
- **Empfehlung:** Zuerst entscheiden, ob die App überhaupt übersetzt werden soll. Wenn ja: Quellsprache auf `de` stellen, Text-Parameter auf `LocalizedStringKey` umstellen und die toten Schlüssel löschen.
- **Sicherheit:** Die Zahlen sind verifiziert. Die Folgen halte ich für plausibel.

**C15 – mittel – Hart codierte Hex-Farben ohne Namen im Produktivcode**
- **Beleg:** 57 Hex-Werte stehen im Produktivcode außerhalb von Theme- und Token-Dateien. Beispiele:
  - `GlassActionButton.swift:29-32` (13 Werte)
  - `LeadingCheckAction.swift:30`
  - `SheetTextField.swift:39`
  - `SheetPriceField.swift:49`
  - `ManageItemsSheet.swift:113`
  - `ItemSearchSheet.swift:120`
- Das Fehler-Rot `#E5484D` steht in 5 Dateien, ohne dass es einen benannten Farbwert dafür gibt.
- **Gut:** Die Akzenttöne `#0FA3AE` und `#1FC2CC` kommen nur im DesignSystem und in Vorschauen vor. Die AccentScale-Regel ist also eingehalten.
- **Empfehlung:** Benannte Farben wie `danger` und `favorite` in `SheetTheme` bzw. `ListTheme` anlegen.
- **Sicherheit:** verifiziert.

**C16 – mittel – Die Schriftskalierung ändert globalen Zustand mitten im `body`**
- **Beleg:** `AppFontScaling.swift:28` schreibt mit `let _ = AppFont.scale = …` im `body` in eine globale Variable. Diese ist als `nonisolated(unsafe)` deklariert (`AppFont.swift:30-31`). Danach baut `.id(dynamicTypeSize)` den gesamten View-Baum neu auf.
- **Folge:** Der versteckte globale Zustand ist schwer zu testen. Beim Ändern der Textgröße geht wahrscheinlich der `@State` aller Views verloren.
- **Empfehlung:** Den Skalierungsfaktor als Environment-Wert weitergeben.
- **Sicherheit:** Der Code ist verifiziert. Den Verlust des Zustands halte ich für plausibel.

**C17 – mittel – Fehler werden an 124 Stellen still verworfen**
- **Beleg:** `try?` ohne Log, zum Beispiel:
  - `AppSessionViewModel+Account.swift:131-132` (Profilbild laden)
  - `BarcodeScanViewModel.swift:62` und `:65`
  - `ReceiptFlowViewModel.swift:67`
  - `ShareMembersViewModel.swift:52`
  - `ListViewModel+Sections.swift:41`
- **Folge:** Wenn dort etwas schiefgeht, steht es in keinem Log.
- **Empfehlung:** An solchen Stellen `do/catch` mit `logVoid` verwenden. `try?` nur dort lassen, wo ein Fehlschlag bewusst egal ist.
- **Sicherheit:** verifiziert.

**C18 – niedrig – Initialisierer mit sehr vielen Parametern**
- **Beleg:** 16 Funktionen oder Initialisierer haben mehr als 5 Parameter:
  - `ItemModel.swift:171` mit 23 und `:226` mit 21
  - `ItemEntity.swift:82` mit 23 und `:187` mit 22
  - `SyncOperation.swift:96` mit 12
- `ItemModel.withId` (Zeile 253) kopiert alle 23 Felder von Hand. Die HLC-Felder (Zeitstempel der Sync-Uhr) stehen einzeln in `ItemModel`, obwohl es dafür den Typ `CRDTMetadata` gibt.
- **Folge:** Kommt ein neues Feld dazu, muss man es an etwa 6 Stellen nachtragen.
- **Empfehlung:** Felder zu Gruppen zusammenfassen, zum Beispiel Sync-Metadaten und Bild.
- **Sicherheit:** verifiziert.

**C19 – niedrig – Kommentare widersprechen dem Code**
- `RootView.swift:10` und `:26`, `FamlistApp.swift:187` und `AppSessionViewModel.swift:19` nennen `AuthView`. Die gibt es nicht mehr.
- `ItemFormViewModel.swift:10` nennt „AddItemView and EditItemView“, `ListViewModel.swift:129` nennt `ItemSearchView`, und `:161` nennt `ListRowView`.
- Insgesamt nennen Kommentare 20 Typnamen, die es nicht gibt.
- 61 Dateiköpfe haben ein veraltetes „Last updated on“. Beispiel: `ListViewModel.swift:8` sagt „18.10.2025“.
- **CLAUDE.md selbst ist veraltet:** Dort steht, `SyncMonitor` sei „noch NICHT in SyncEngine integriert“. Er ist aber eingebunden (`SyncEngine.swift:63`, `:196`, `:278`).
- **Empfehlung:** Die Kommentare und CLAUDE.md korrigieren. Die Datumszeile im Dateikopf streichen, weil Git das Datum ohnehin kennt.
- **Sicherheit:** verifiziert.

**C20 – niedrig – Kommentare sind oft überflüssig und die Sprache ist gemischt**
- **Überflüssige Kommentare:** 620 Code-Zeilen haben einen Kommentar dahinter, der oft nur den Code wiederholt. Beispiel in `ItemModel.swift:199` ff.: „// Assigns the item's name“. In 47 Dateien steht sogar hinter `import SwiftUI` ein Kommentar. Die meisten solchen Kommentare haben `FamlistApp.swift` (45) und `RootView.swift` (35).
- **Gemischte Sprache:** 2.283 Kommentarzeilen sind deutsch und 1.453 englisch; 41 Dateien mischen beides. Die Bezeichner im Code sind durchgehend englisch.
- **Empfehlung:** Eine Kommentarsprache festlegen und die wiederholenden Kommentare streichen.
- **Sicherheit:** verifiziert.

**C21 – niedrig – Die Regel „ein Typ pro Datei“ ist in 23 Dateien verletzt**
- **Beleg:** In 23 Dateien stehen nicht-private Zusatztypen. Beispiele:
  - `Core/Networking/SupabaseClient.swift` enthält 5 Typen.
  - Protokoll-Dateien enthalten gleich ihre Vorschau- bzw. In-Memory-Umsetzungen: `ItemsRepository.swift`, `ItemCatalogRepository.swift`, `GlobalProductCatalogRepository.swift`, `CategoryDefinitionsRepository.swift`, `PricePointsRepository.swift`, und `ImageStorage.swift` enthält `SupabaseImageStorage`.
- Die übrigen 21 der 44 Dateien mit mehreren Typen haben nur private Hilfstypen. Das ist nach der Regel erlaubt.
- `SyncEngine.swift` ist mit 304 Zeilen die einzige Datei über der 300-Zeilen-Grenze.
- **Empfehlung:** Die Zusatztypen in eigene Dateien verschieben.
- **Sicherheit:** verifiziert.

**C22 – niedrig – `Font.system` statt `AppFont`**
- **Beleg:** `ReceiptReviewSheet.swift:150` und `ShareMembersSheet.swift:199` nutzen `.system(size:…, design: .monospaced)`.
- **Folge:** Das verletzt die Schriftregel. Allerdings bietet `AppFont` keine Schrift mit fester Zeichenbreite.
- **Empfehlung:** In `AppFont` eine `mono`-Variante ergänzen oder die Ausnahme in CLAUDE.md festhalten.
- **Sicherheit:** verifiziert.

**C23 – niedrig – Kleinere Stellen bei Typsicherheit und Idiomatik**
- `ListViewModel+ItemCRUD.swift:114` loggt `brand: normalized.brand ?? "nil"`, also den Text „nil“ statt eines fehlenden Werts.
- `ShareMembersViewModel.swift:50` und `:53` speichern die Rolle als deutschen Text „Besitzer“ statt als Enum.
- `SyncEngine.swift:265` nutzt einen `Timer` für die Abfrage-Schleife statt einer `Task`-Schleife.
- 10 Dateien nutzen Combine (`AnyPublisher`, `sink`) parallel zu async/await.
- Die Force-Unwraps sind alle sicher begründet:
  - `ImportMergeService.swift:91` und `:98`: der Schlüssel wurde direkt davor gesetzt.
  - `OnboardingService.swift:80`: `randomElement()` auf einer festen, nicht leeren Zeichenliste.
  - `PaginationCursor.swift:49`: die Zeitzone „UTC“ existiert immer.
- Der einzige `fatalError` (`PersistenceController.swift:91`) ist die letzte Rückfallebene, wenn selbst der In-Memory-Speicher scheitert. Das ist vertretbar.
- **Sicherheit:** verifiziert.

## Gesamteinschätzung

Die Grundhygiene ist gut:
- Es gibt keine TODO/FIXME, keinen auskommentierten Code, keine SF Symbols, kein `AnyView` und kein `try!`.
- `UserLog` wird nur in ViewModels aufgerufen, und die Entwickler-Logs laufen nur im Debug-Build.
- Nur eine Datei überschreitet 300 Zeilen.

Die größten Probleme stammen aus dem Redesign:
- Die Listen-Oberfläche existiert als Design-Kopie ein zweites Mal (C1).
- Es gibt viel toten Code, tote Assets und tote Katalog-Schlüssel (C5, C6, C7, C14).
- Hilfsfunktionen für Preise, Anzeigenamen, Datum und Wartezeiten sind mehrfach geschrieben (C9 bis C12).

Die Funktionslänge ist bestätigt: 98 Funktionen sind länger als 30 Zeilen, 40 davon sind View-Bodies. Die meiste Wirkung versprechen drei Schritte: toten Code löschen, die Design-Kopie klären und die Realtime-Verarbeitung auf `SupabaseItemRow` umstellen. Der Datumsfehler in C2 ist nur plausibel; ein Unit-Test mit einer echten Realtime-Nachricht würde ihn bestätigen oder widerlegen.

---

## SwiftUI, Design, Accessibility (U)

# UI-Audit Famlist (Branch audit-fixes, HEAD 7d54889)

Ich habe nur gelesen und keine Datei geändert. Belegt ist jeder Befund mit grep-Ergebnissen, zwei Hilfsskripten im Scratchpad und dem Lesen des Codes. „Verifiziert“ heißt: Der Code steht so da. „Plausibel“ heißt: Die Folge ist abgeleitet, aber nicht mit Instruments oder auf dem Gerät gemessen.

## Befunde

### Zustand und Performance

**U1 – mittel – Der Hauptscreen beobachtet zu viel und sortiert die Liste bei jeder Änderung neu**
- **Wo:** `ShoppingListView.swift:34-37`, `ShoppingListContent.swift:44`, `ListViewModel+Sections.swift:25`, `RootView.swift:29`.
- **Beleg:**
  - `ListViewModel` hat 21 `@Published`-Felder, `AppSessionViewModel` hat 12.
  - `ShoppingListView` beobachtet 4 Objekte: ListVM, Session, CategoryStore und PriceBook.
  - `ShoppingListContent` ruft bei jedem Neuzeichnen `visibleSections` auf. Das läuft über `ListSectionBuilder` und filtert und sortiert alle Artikel.
  - Auch reine Hilfsfelder lösen das aus, zum Beispiel `recentlySyncedItemIDs` (ändert sich 2× pro Realtime-Ereignis), `isLoadingNextPage`, `listItemCounts` oder `activeListMembers`.
  - `RootView` beobachtet das ListViewModel, liest aber keinen Wert daraus.
- **Folge:** Bei großen Listen und vielen Realtime-Ereignissen wird der ganze Bildschirm oft neu berechnet (plausibel).
- **Empfehlung:**
  - Die Abschnitte im ViewModel einmal pro Änderung von `items`, `sortSettings`, `itemFilter`, `manualOrder` oder `categoryOrder` berechnen und speichern.
  - Den `@EnvironmentObject` in `RootView` entfernen.
  - Langfristig auf `@Observable` umstellen. Dann wird nur neu gezeichnet, wer ein Feld wirklich liest.
- **Sicherheit:** Code verifiziert, Wirkung plausibel.

**U2 – mittel – Jede Artikelkarte zeichnet etwa 7 Schattenebenen einzeln außerhalb des Bildschirms**
- **Wo:** `CSSBox.swift` (DropShadowLayer/InnerShadowLayer mit `compositingGroup` + `blur` + `blendMode`), `ListTheme.swift:80-88`.
- **Beleg:** Im Dark Mode hat eine Karte 7 Schattenebenen: 2 für die Karte, 2 für das Bild, 1 für den Mengen-Chip und 2 für den Abhak-Kreis. Jede Ebene wird außerhalb des Bildschirms zusammengesetzt und weichgezeichnet.
- **Folge:** Scrollen kann auf älteren iPhones ruckeln (plausibel).
- **Empfehlung:** Mit Instruments (Core Animation, Offscreen Passes) messen. Danach die Karte per `.drawingGroup()` in ein Bild zusammenfassen oder Schatten mit `blur == 0` ohne `compositingGroup` zeichnen.
- **Sicherheit:** plausibel.

**U3 – niedrig – SVG-Pfade werden bei jedem Zeichnen neu eingelesen**
- **Wo:** `SVGIconShape.swift:23-28`.
- **Beleg:** `SVGPathParser.parse(d)` zerlegt den Pfad-Text bei jedem Aufruf von `path(in:)`. Es gibt keinen Zwischenspeicher. Es gibt 97 Stellen mit `SVGIcon`, und das Dock animiert laufend.
- **Folge:** Unnötige Rechenzeit, vor allem während Animationen (plausibel).
- **Empfehlung:** Einen statischen Zwischenspeicher `[String: Path]` einbauen, der mit einer Sperre geschützt ist.
- **Sicherheit:** Code verifiziert, Kosten plausibel.

**U4 – mittel – „Artikel verwalten“ zeichnet den ganzen Artikelstamm auf einmal**
- **Wo:** `ManageItemsSheet.swift:72-79`, `:103`, `:190`, `:229`.
- **Beleg:**
  - Die Liste steht in einem normalen `VStack`, nicht in einem `LazyVStack`. Alle Karten werden also sofort gebaut.
  - Jede Zeile hat einen eigenen `GeometryReader`, nur für den Pfeil rechts.
  - Jede Zeile dekodiert ihr Bild über `ImageCache` direkt beim Zeichnen.
  - `vm.visibleEntries` filtert pro Zeichnen den ganzen Stamm mit `lowercased()` und wird zweimal pro Zeichnen aufgerufen (Zähler und Liste).
- **Folge:** Bei einigen hundert Einträgen öffnet sich das Sheet langsam, und die Suche reagiert träge (plausibel).
- **Empfehlung:** `LazyVStack` verwenden, das gefilterte Ergebnis im ViewModel speichern und den Pfeil ohne `GeometryReader` zeichnen.
- **Sicherheit:** Code verifiziert.

**U5 – niedrig – Bilder werden beim Zeichnen synchron dekodiert**
- **Wo:** `ItemModel+Display.swift:29-30`, `ItemCard.swift:48`, `SearchResultCard.swift:76`, `ManageItemsSheet.swift:229`.
- **Beleg:**
  - `item.image` dekodiert beim ersten Aufruf Base64 und `UIImage(data:)` auf dem Hauptthread.
  - Der Schlüssel im `NSCache` ist der ganze Base64-Text. Bei einem Treffer wird deshalb die ganze Zeichenkette verglichen.
- **Folge:** Beim ersten Scrollen durch eine Liste mit Fotos kann es kurz hängen (plausibel).
- **Empfehlung:** Im Hintergrund dekodieren, als Schlüssel die Artikel-ID oder einen Hash verwenden und Vorschaubilder vorab verkleinern.
- **Sicherheit:** verifiziert.

**U6 – niedrig – ViewModels werden im body der Eltern-View erzeugt und sofort verworfen**
- **Wo:** `ShoppingListView+Sheets.swift:109` (BarcodeScanViewModel), `:146` (ShareMembersViewModel), `ShoppingListView+Receipts.swift:47,52` (PriceHistoryViewModel).
- **Beleg:** Die Sheets übernehmen das Objekt mit `StateObject(wrappedValue:)`. Behalten wird nur das erste. Bei jeder Änderung am ListViewModel entsteht trotzdem ein neues Objekt, das gleich wieder weggeworfen wird.
- **Zweites Problem:** `ManageItemsSheet.swift:34` benutzt `@StateObject` für ein Objekt, das `ShoppingListView` in `@State var manageItemsVM` besitzt. Wem das Objekt gehört, ist dadurch unklar.
- **Folge:** Unnötige Objekte und ein Risiko, sobald ein `init` Nebenwirkungen bekommt.
- **Empfehlung:** Den ViewModel-Aufbau als `@autoclosure` übergeben oder im Sheet selbst erzeugen. Für fremd besessene Objekte `@ObservedObject` verwenden.
- **Sicherheit:** verifiziert.

**U7 – niedrig – Zwei `@Published`-Felder werden von keiner View gelesen**
- **Wo:** `AppSessionViewModel.swift:78, 147-156` (`toastMessage`), `ListViewModel.swift:48` (`selectedItem`, im Kommentar selbst „Legacy“ genannt).
- **Beleg:** grep findet keinen Leser von `toastMessage`. Das Feld wird beim Kaltstart 4× gesetzt, einmal pro `markPhase` (`AppSessionViewModel+Auth.swift:99,134,144,155`).
- **Folge:** Jede Änderung lässt alle 8 Views, die die Session beobachten, neu zeichnen – ohne sichtbaren Effekt.
- **Empfehlung:** Beide Felder entfernen oder zu einfachen Variablen ohne `@Published` machen.
- **Sicherheit:** verifiziert.

### Logik in Views

**U8 – mittel – ShoppingListView ist ein Koordinator voller Geschäftsregeln**
- **Wo:** `ShoppingListView+Sheets.swift:192-294`, `+Receipts.swift:77-115`, `ShoppingListView.swift:103`.
- **Beleg:** Folgende Regeln stehen in der View statt im ViewModel:
  - Artikel aus dem Scanner zusammenbauen (`addScanned`).
  - Eine Liste anlegen und danach als Favorit setzen.
  - Bei Kategorie ändern oder löschen die Artikel über zwei Stores neu zuordnen.
  - Entscheiden, ob „Löschen“ die Liste löscht (Eigentümer) oder sie nur verlässt (Mitglied).
  - Den letzten Preis mit mehreren Ausweichstufen suchen (`lastPriceText`).
  - Preise mitschreiben.
  - Den CategoryStore über `.onReceive` in das ListViewModel spiegeln.
- **Folge:** Diese Regeln sind ohne UI nicht testbar. Außerdem gilt die Spiegelung der Kategorien nur, solange `ShoppingListView` im Baum steht.
- **Empfehlung:** Einen `ShoppingCoordinator` oder Methoden im ViewModel einführen, etwa `addFromCatalog(entry:quantity:barcode:)`, `removeList(_:)` und `renameCategory(...)`. Die Kategorien direkt im ViewModel abonnieren.
- **Sicherheit:** verifiziert.

**U9 – mittel – Benutzernamen-Prüfung, Foto-Upload und Speichern sind doppelt gebaut**
- **Wo:** `EditProfileSheet.swift:141-151, 166-174` und `ProfileSetupView.swift:129-139, 236-242`.
- **Beleg:** In beiden Views stehen dieselben Schritte als `@State` plus `Task`:
  - `.task(id: username)` mit 350 ms Wartezeit und danach `session.checkUsername`.
  - `onChange(of: photo)`, dann `loadTransferable`, dann `UIImage(data:)`, dann `uploadAvatar`.
  - Beim Speichern `saveProfile` und bei einem Fehler eine erneute Prüfung.
- **Folge:** Eine Korrektur an einer Stelle fehlt leicht an der anderen.
- **Empfehlung:** Ein gemeinsames `ProfileFormViewModel` einführen.
- **Sicherheit:** verifiziert.

**U10 – mittel – Die Toast-Logik gibt es viermal, und nur eine Kopie ist barrierefrei**
- **Wo:** `ShoppingListView+Overlays.swift:154-164`, `SignInView.swift:217-226`, `AcceptInviteView.swift:123-133`, `ShareMembersSheet.swift:60-70`.
- **Beleg:**

| Stelle | Anzeigedauer | Abstand unten | VoiceOver-Ansage | „Bewegung reduzieren“ |
|---|---|---|---|---|
| Liste (`ShoppingListView+Overlays.swift`) | 3 s | `dockBottom + 80` | ja (Zeile 157) | ja |
| SignIn | 4 s | 40 | nein | nein |
| AcceptInvite | 4 s | 40 | nein | nein |
| ShareMembers | 4 s | 40 | nein | nein |

- **Folge:** Blinde Nutzer hören zum Beispiel „Anmeldelink gesendet“ oder „konnte nicht entfernt werden“ nicht.
- **Empfehlung:** Einen Modifier `.statusToast(message:isError:duration:)` bauen, der die Ansage und „Bewegung reduzieren“ einmal zentral erledigt.
- **Sicherheit:** verifiziert.

**U11 – niedrig – Formular-Prüfung wird aus der View angestoßen**
- **Wo:**
  - `NewItemSheet.swift:69-70`, `EditItemSheet.swift:79-81`: 5× `.onChange` für `validateField`.
  - `ItemSearchSheet.swift:67`: `.onChange` ruft `onSearchTextChanged`.
  - `ItemSearchSheet.swift:160-168`: `add` bricht still ab, wenn `defaultList` noch `nil` ist. Es schreibt dann nur einen Log.
  - `ShoppingListView+Sheets.swift:193`: `addScanned` fügt dagegen auch ohne Eigentümer hinzu.
- **Folge:** Solange die Liste noch lädt, reagiert „+“ in der Suche nicht, der Scanner aber schon (plausibel).
- **Empfehlung:** Prüfen per `didSet` im ViewModel. Hinzufügen aus Suche und Scanner über eine einzige ViewModel-Methode, die dieselbe Regel für den Eigentümer anwendet.
- **Sicherheit:** verifiziert.

### Wiederverwendung und Design-System

**U12 – mittel – Rund 780 Zeilen Design-Kopien laufen im Release mit, obwohl sie nur Vorschauen dienen**
- **Wo:** `Shared/Components/Hybrid/Design/` mit DesignListScreen, DesignItemRow, DesignProgressHero, DesignListTopBar, DesignListTabs, DesignListSearchField, DesignSectionHeader und DesignListEmptyState.
- **Beleg:**
  - Diese Dateien sind zweite Fassungen von ItemCard, ProgressHero, ListTopBar, ListFilterTabs, ListSearchBar, ListSectionHeader und ListEmptyState.
  - `DesignListScreen` wird nur gezeichnet, wenn `hybridHosted == false` ist. Das ist nur in Vorschauen der Fall (SheetScreen, EKKSheetStage, ListAccountBackdrop, OverlayStage).
  - Die Kopien laufen schon auseinander. Beispiel: ProgressHero hat 19 und DesignProgressHero 18 eingebaute Farben.
- **Folge:** Vorschauen zeigen einen anderen Stand als die App, und der doppelte Code muss gepflegt werden.
- **Empfehlung:** Vorschauen mit den echten Komponenten und `PreviewMocks` bauen. Alternativ die Design-Dateien mindestens in `#if DEBUG` setzen.
- **Sicherheit:** verifiziert.

**U13 – niedrig – Konkrete Duplikatpaare**

| Duplikat | Stellen | Vorschlag |
|---|---|---|
| Dunkler Bildschirm-Hintergrund, identisch | `ListBackground.swift` (`base`, `#071012` + Radial) und `EKKScreenBackground.swift:26-33` | `ScreenBackground` |
| Abschnitts-Label 13/600, 0.52, Großbuchstaben, sub, Abstand 4 | `EKKSectionLabel`, `ListAccountSectionLabel`, dazu inline `MyListsSheet.swift:62-68` und `ItemSearchSheet.swift:122-127` | `SectionCapsLabel` |
| Kamera-Kopfzeile, Glas-Knopf 48 und Verlauf | `BarcodeScanSheet.swift:57, 68-80, 132-143` und `ReceiptCaptureView.swift:41, 76-95, 179-190` | `CameraTopBar`, `CameraGlassButton` |
| Sheet-Bühne (Hintergrund, Weichzeichner, Abdunkelung) | `SheetScreen.swift`, `EKKSheetStage.swift`, `ListAccountBackdrop.swift` | eine generische `DesignStage` |
| Abstand unten `keyboardHeight > 0 ? +14 : 34` | NewItemSheet:47, EditItemSheet:60, ItemSearchSheet:52, ListNameSheet:46 | `SheetFooterCTA` |
| `unitsBinding` | NewItemSheet:102, EditItemSheet:157 | gemeinsame Formularteile |
| Tastatur schließen per `resignFirstResponder` | ShoppingListView:169, SignInView:228 | gemeinsame Hilfsfunktion |

Sicherheit: verifiziert.

**U14 – mittel – Sheets verhalten sich unterschiedlich**
- **Beleg:** Nach unten wischen zum Schließen gibt es nur in `HybridSheetLayer.swift:46-56`. `DragGesture` kommt sonst nirgends vor. Die Sheets sind so verteilt:
  - **Mit Wischen (8 Sheets):** Suche, Neu, Bearbeiten, Produktbild, Import, Meine Listen, Listenname und alles, was darauf aufbaut.
  - **Ohne Wischen, über ListAccountSheet:** Einstellungen, Profil, Liste anlegen, Teilen.
  - **Ohne Wischen, direkt auf SheetSurface:** Artikel verwalten, Preisverlauf, Kassenzettel prüfen, Kategorien, Kategorie bearbeiten.
- **Folge:** Nutzer finden je nach Sheet eine andere Bedienung vor.
- **Empfehlung:** Alle Sheets über `HybridSheetLayer` führen oder die Wischgeste in `SheetSurface` verlegen.
- **Sicherheit:** verifiziert.

**U15 – mittel – Es gibt zwei Wisch-Zeilen, und die zweite ist schwächer**
- **Wo:** `SwipeableItemRow` (Hauptliste) und `SwipeToDeleteRow.swift:33-57` (Artikelstamm, Kategorien, Mitglieder).
- **Beleg:** Der zweiten Zeile fehlen drei Dinge:
  - „Bewegung reduzieren“ wird nicht beachtet.
  - Es ist nicht geregelt, dass nur eine Zeile gleichzeitig offen ist.
  - Wischt man über 60 % der Breite, wird sofort gelöscht, ohne Rückgängig.
- **Konkret:** `ShareMembersSheet.swift:89` entfernt so ein Mitglied sofort. `ShareMembersViewModel.remove` ruft dabei direkt den Server auf und ist damit nicht offline-first.
- **Folge:** Ein Mitglied kann versehentlich entfernt werden (plausibel).
- **Empfehlung:** Eine gemeinsame Wisch-Komponente bauen und für destruktive Aktionen Rückgängig oder eine Rückfrage vorsehen.
- **Sicherheit:** verifiziert.

**U16 – niedrig – Farben stehen außerhalb der Tokens, und es gibt 6 Token-Typen parallel**
- **Beleg:**

| Farbe / Wert | Wofür | Wo |
|---|---|---|
| `#E5484D` | Fehlerrot | SheetTextField:39, SheetPriceField:49, ItemSearchSheet:120, ManageItemsSheet:113, GlassActionButton, DesignItemRow |
| `#F5B521` | Favorit / Gold | 6 Dateien |
| `#FFC08A` / `#BD5F0E` | Warnung | ItemCard:88,129, GlassActionButton, DesignItemRow |
| Gold-Verlauf | Rückgängig-Knopf | UndoActionButton:40 und DesignItemRow:122 |
| Kamera-Verlauf | Scanner / Kassenzettel | 2 Dateien |
| `.rgba(` | Farben inline | 133× außerhalb von Token-Dateien |

- **Token-Typen:** ListTheme, SheetTheme, OverlayTheme, EKKTokens, ListAccountTokens und ItemExtraTokens.
- **Folge:** Ändert sich eine Farbe im Design, muss man sie an vielen Stellen suchen.
- **Empfehlung:** Semantische Farben (`danger`, `favorite`, `warning`) in einen gemeinsamen Basis-Token legen.
- **Sicherheit:** verifiziert.

**U17 – niedrig – Drei Textfelder mit unterschiedlicher Fokus-Anzeige**
- **Beleg:**
  - `SheetTextField` zeigt den Fokusring dynamisch.
  - `ListAccountFocusedField` zeigt den Ring immer, auch ohne Fokus.
  - `EKKInputField` zeigt nie einen Ring. Das betrifft Anmelden und Profil einrichten.
- **Folge:** Auf den Einstiegs-Screens sieht man nicht, welches Feld aktiv ist.
- **Empfehlung:** Ein gemeinsames Feld bauen, dessen Ring vom Fokus abhängt. Danach mit dem Design abgleichen, ob der Dauerring gewollt ist.
- **Sicherheit:** Code verifiziert, Design-Absicht nicht geprüft.

### Barrierefreiheit

**U18 – niedrig bis mittel – Tippflächen unter 44 pt**
- **Beleg:**
  - Filter-Chips 36 pt (`ManageItemsSheet.swift:159`).
  - Erscheinungsbild-Segment 40 pt (`SettingsSheet.swift:192`).
  - `ListAccountToggle` 31 pt hoch (`ListAccountToggle.swift:40`); die Zeile drumherum ist nicht tippbar.
  - `CategoryChipRow` 42 pt (`CategoryChipRow.swift:44,60`).
  - `ListFilterTabs` etwa 42 pt (Schätzung aus 15 pt Text + 22 pt Abstand).
- **Folge:** Diese Elemente sind schwerer zu treffen, besonders für Menschen mit motorischen Einschränkungen.
- **Empfehlung:** Die Trefferfläche vergrößern, ohne die Optik zu ändern (`contentShape` mit Rand). Die ganze Einstellungs-Zeile als Schalter tippbar machen.
- **Sicherheit:** verifiziert (Tabs geschätzt).

**U19 – niedrig – `onTapGesture` statt Button**
- **Wo:** `SearchResultCard.swift:69` (ganze Karte) und `MyListsSheet.swift:87-88` (Tippen plus langer Druck).
- **Beleg:** Bei der Suchkarte ist für VoiceOver nur der „+“-Knopf ein Button. Die Karte selbst hat keine Button-Eigenschaft. `MyListsSheet` hat Label, Button-Eigenschaft und eine eigene Aktion und ist damit in Ordnung.
- **Empfehlung:** Die Suchkarte zu einem Element zusammenfassen, das `.isButton` trägt und „hinzufügen“ als Label hat.
- **Sicherheit:** verifiziert.

**U20 – niedrig – „Bewegung reduzieren“ wird oft nicht beachtet**
- **Beleg:** Federn ohne Prüfung stehen an diesen Stellen:
  - `ShoppingListContent.swift:74-76, 86, 109`
  - `ListFilterTabs`, `ProgressHero.swift:148`, `HybridSheetLayer.swift:63`
  - `SwipeToDeleteRow`, `SheetQuantityStepper`, `OverlaySwitch`
  - `BarcodeScanSheet.swift:122`, `ReceiptCaptureView.swift:198`
  - SignIn, AcceptInvite, ShareMembers
- **Dazu:** `withAnimation` steht auch in ViewModels (`ListViewModel+UndoDelete.swift:52,73,87`, `+Sections.swift:65`, `+BulkActions.swift:278`). Dort ist die Einstellung gar nicht abfragbar.
- **Empfehlung:** Einen gemeinsamen `motion(_:)`-Helfer aus der Umgebung verwenden und Animationen aus den ViewModels in die Views verlegen.
- **Sicherheit:** verifiziert.

**U21 – niedrig – Dynamic Type hat Grenzen und Nebenwirkungen**
- **Deckel:** `AppFont.maxScale` begrenzt die Schrift auf XXL (+24 %). Die Barrierefreiheits-Größen AX1 bis AX5 bringen darüber hinaus nichts mehr. Das ist laut Kommentar bewusst entschieden und hier nur zur Kenntnis erwähnt.
- **Neuaufbau:** `AppFontScaling` setzt `.id(dynamicTypeSize)` an der Wurzel der App. Ändert jemand die Textgröße, während die App läuft, gehen offene Sheets und eingetippter Text verloren (plausibel).
- **Nebenwirkung im body:** `AppFont.scale` ist ein globaler Wert, der im `body` gesetzt wird.
- **Monospace-Schrift:** `ReceiptReviewSheet.swift:150` und `ShareMembersSheet.swift:199` wachsen nicht mit. Die Schrift selbst schreibt das Design vor und ist korrekt.
- **Sicherheit:** Code verifiziert, Folgen plausibel.

### Lokalisierung

**U22 – mittel – Die Übersetzungsdatei ist nur halb gepflegt**
- **Beleg:**
  - Das String-Catalog hat `sourceLanguage en`. Im Projekt steht `knownRegions` nur auf `en` und `Base`; `de` fehlt.
  - Von 85 `Text("…")`-Texten ohne Platzhalter stehen nur 4 im Catalog.
  - `Text(stringVariable)` wird nicht übersetzt. Beispiele: `ShoppingListContent.swift:139-140`, Sheet-Titel, die als `String` übergeben werden.
  - Enum-Rohwerte dienen als Anzeigetext: `ItemFilter` („Alle“ usw.) und `ListAccountAppearanceChoice` („Hell“). Der Wert „Hell“ wird zusätzlich in `@AppStorage` gespeichert (`SettingsSheet.swift:188`). Wer den Anzeigetext umbenennt, verliert die gespeicherte Einstellung.
  - Der Catalog enthält 0 Plural-Varianten. Die Mehrzahl entsteht per Ternary, z. B. `ListSummaryCard:53`, `MyListsSheet:62`, `AcceptInviteView:69-70`, `ClipboardImportSheet:144`.
- **Folge:** Die App ist faktisch nur auf Deutsch nutzbar. Eine zweite Sprache wäre ein großer Umbau. Eine Umbenennung kann die Einstellung zurücksetzen.
- **Empfehlung:** Den Catalog auf `de` als Quellsprache umstellen, Enums einen eigenen Anzeigetext geben und Plural-Varianten im Catalog verwenden.
- **Sicherheit:** verifiziert.

**U23 – niedrig – Zahlen- und Datumsformate sind fest verdrahtet**
- **Beleg:**
  - `de_DE` und EUR stehen an 6 Stellen fest im Code: `PriceDisplaySetting:31`, `ReceiptReviewSheet:128,153`, `ShoppingDoneView:93`, `PriceHistoryViewModel:71,77,85`.
  - `ReceiptReviewSheet.swift:111` nutzt dagegen die Sprache des Geräts.
  - `PriceHistoryViewModel.monthLabels` erzeugt bei jedem Zugriff einen neuen `DateFormatter`. Die Eigenschaft wird aus dem body aufgerufen (`PriceHistorySheet.swift:84`).
- **Empfehlung:** Einen zentralen `Formatters`-Typ mit statischen Instanzen anlegen und die Locale an einer Stelle bewusst festlegen.
- **Sicherheit:** verifiziert.

## Nicht als Befund gemeldet

- Deine bekannten offenen Punkte: CTA-Kontrast, blasse Einladungskarte im Dark Mode, „0 von 1 Artikel“, Fehler-Toast ohne Design und ShoppingDone ohne Kassenzettel.
- Die Monospace-Schrift selbst, weil das Design `ui-monospace` vorschreibt.
- Die grauen Eingabetexte in `EKKInputField`, weil das Design `color: k.sub` vorschreibt.

## Gesamteinschätzung

Die UI-Schicht ist handwerklich sauber:
- Es gibt 0 SF Symbols, 0 `AnyView` und kein `NavigationView`.
- Überall wird die neue `onChange`-Signatur verwendet.
- Offene Sheets sind ein Enum (`ActiveListSheet`) statt mehrerer Bools.
- Jede Datei mit einem View-Typ hat eine `#Preview` in Light und Dark, ohne Netzwerk. Ausgenommen ist nur `UITestFixture`.
- Icon-Knöpfe haben durchweg Labels (69 Labels, 48× `accessibilityHidden`). Sheets setzen `isModal` und reagieren auf die VoiceOver-Geste „Zurück“.

Die größten Schwächen liegen woanders:
- **Performance:** Zu breite Beobachtung des `ListViewModel` sorgt für häufiges Neuberechnen und Sortieren (U1). Dazu kommen teure Schatten pro Karte (U2).
- **Logik in Views:** `ShoppingListView` wächst zu einem Koordinator mit Geschäftsregeln (U8).
- **Wiederverwendung:** Viele fast gleiche Bausteine (U9–U15) führen schon jetzt zu uneinheitlichem Verhalten, etwa beim Wischen zum Schließen, bei Toasts und bei Wisch-Zeilen.
- **Lokalisierung:** Die App ist in der Praxis nur auf Deutsch nutzbar (U22).

Als erste Schritte empfehle ich U1, U10 und U14. Sie bringen mit wenig Aufwand den meisten Nutzen für Nutzer.

Relevante Dateien:
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Features/ShoppingList/Views/ShoppingListView.swift`
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Features/ShoppingList/Views/ShoppingListContent.swift`
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Features/ShoppingList/Views/ShoppingListView+Sheets.swift`
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Core/DesignSystem/Hybrid/Rendering/CSSBox.swift`
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Shared/Components/Hybrid/HybridSheetLayer.swift`
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Features/ItemManagement/Components/SwipeToDeleteRow.swift`
- `/Users/robertbogner/GitPrivate/Famlist/Famlist/Shared/Resources/Localizable.xcstrings`

---

## Backend, Datenbank, Sicherheit (B)

# Backend-Sicherheitsaudit Famlist (nur lesend)

**Geprüfter Stand:** Branch audit-fixes, HEAD 7d54889, Supabase-Projekt mbfztpbwfktiduemqqfe.

**Vorgehen:** Ich habe keine Datei geändert. Auf der Datenbank liefen nur SELECT-Abfragen, Katalogabfragen, ein `EXPLAIN` ohne ANALYZE und `get_advisors`.

**Nicht erreichbar:** Der Atlassian-Server braucht eine Anmeldung. Der GitHub-MCP-Server konnte keine Verbindung aufbauen (Fehler 400). Für dieses Audit waren beide nicht nötig.

## Advisor-Ergebnisse

| Art | Stufe | Anzahl | Inhalt |
|---|---|---|---|
| Sicherheit | ERROR | 0 | – |
| Sicherheit | WARN | 7 | 5× SECURITY-DEFINER-Funktion durch angemeldete Nutzer aufrufbar: `accept_list_invite`, `create_list_invite`, `delete_my_account`, `invite_preview_by_token`, `is_username_available`. Alle fünf sind so gewollt und prüfen `auth.uid()`. Dazu 1× Leaked-Password-Schutz aus und 1× Postgres `17.4.1.074` mit offenen Sicherheits-Patches. |
| Leistung | WARN | 0 | Keine Warnung zu `auth.uid()` ohne Zwischenspeicher, doppelten Regeln oder Fremdschlüsseln ohne Index. |
| Leistung | INFO | 2 | Ungenutzt sind `idx_profiles_favorite_list` und `idx_categories_profile_position`. Beide sollten bleiben, weil sie den Fremdschlüssel bzw. die Sortierung abdecken. |

## Befunde

**B1 – hoch – Die Tabellen items, lists und categories stehen noch in der Realtime-Publication (bekannt, aber größer als gedacht)**
- **Ort:** Publication `supabase_realtime`.
- **Beleg:** `pg_publication_tables` enthält `items` mit allen Spalten einschließlich `imagedata`, dazu `lists` und `categories`. `items` hat `relreplident = f`, also REPLICA IDENTITY FULL. Die App nutzt nur noch Broadcast: `SupabaseRealtimeManager.swift:78` mit `isPrivate = true`, und `postgres_changes` kommt im Code nicht mehr vor.
- **Szenario:** Jeder angemeldete Nutzer kann sich weiterhin auf Postgres Changes dieser drei Tabellen anmelden. Laut Supabase-Doku filtert RLS DELETE-Ereignisse nicht. Er sieht dann die IDs gelöschter Zeilen aller Nutzer und den Zeitpunkt der Löschung. Außerdem prüft Realtime jede Änderung einzeln auf einem Thread. Das wird bei 250.000 Nutzern zum Engpass, und der nächtliche Tombstone-Löschlauf erzeugt Massen-Ereignisse.
- **Empfehlung:** `ALTER PUBLICATION supabase_realtime DROP TABLE items, lists, categories`, sobald keine alte App-Version mehr im Umlauf ist. REPLICA IDENTITY auf DEFAULT zurücksetzen.
- **Sicherheit:** Die Publication ist verifiziert. Das DELETE-Leck ist plausibel, weil es aus der Supabase-Doku folgt; ich habe es nicht live nachgestellt.

**B2 – mittel – `items.imagedata` lässt sich über die REST-Schnittstelle weiter beschreiben, ohne Größengrenze**
- **Ort:** `items`, Migration 020, Zeilen 126–145.
- **Beleg:** Migration 020 sperrt das Base64-Feld nur in der Funktion `upsert_items_lww`. Angemeldete Nutzer haben aber das UPDATE-Recht auf alle Spalten, und für `imagedata` gibt es keinen CHECK. Eine Zeile hat heute schon 599.540 Zeichen.
- **Szenario:** Ein Mitglied schreibt mit `PATCH /rest/v1/items` sehr große Texte in `imagedata`. Die Datenbank wächst, und über B1 gehen diese Daten per Postgres Changes hinaus.
- **Empfehlung:** `REVOKE UPDATE (imagedata), INSERT (imagedata) ON items FROM authenticated` oder einen CHECK wie `imagedata IS NULL OR length(imagedata) <= 0` für neue Zeilen. Danach die Spalte entfernen.
- **Sicherheit:** verifiziert.

**B3 – mittel – Mitglieder dürfen Artikel endgültig löschen und umgehen damit CRDT und LWW**
- **Ort:** Policy `items_access` mit `FOR ALL`.
- **Beleg:** Die Policy erlaubt auch DELETE. Der LWW-Trigger `items_lww_guard` greift nur bei INSERT und UPDATE. Die App löscht Artikel nie endgültig; eine Suche nach `.delete()` findet keine Stelle an `items`.
- **Szenario:** Ein böswilliges oder fehlerhaftes Mitglied löscht mit einem einzigen Aufruf alle Artikel einer geteilten Liste. Es gibt keinen Tombstone, keine Historie und keinen LWW-Vergleich.
- **Empfehlung:** Die Policy in SELECT, INSERT und UPDATE aufteilen und keine DELETE-Regel für Clients anlegen.
- **Sicherheit:** verifiziert.

**B4 – mittel – Direkte REST-Schreibzugriffe umgehen die Schutzregeln der Upsert-Funktion (enthält bekannte Punkte)**
- **Ort:** `items`, `upsert_items_lww` (Migration 020, Zeilen 151 und 163) und `items_lww_guard` (Migration 015, Zeile 44).
- **Beleg:**
  - Die Funktion behält den Ersteller mit `coalesce(t.ownerpublicid, …)` bei. Ein direkter PATCH überschreibt `ownerpublicid` trotzdem.
  - `last_modified_by` wird ungeprüft aus der Anfrage übernommen. Das war bekannt und ist bestätigt.
  - HLC-Zeitstempel dürfen bis zu 86.400.000 ms (24 Stunden) in der Zukunft liegen. Das war bekannt und ist bestätigt.
- **Szenario:** Ein Mitglied schreibt Artikel einem anderen Nutzer zu. Mit einem Zeitstempel knapp unter 24 Stunden in der Zukunft gewinnt es einen Tag lang jeden Konflikt.
- **Empfehlung:** Ein BEFORE-Trigger setzt `last_modified_by := auth.uid()` und macht `ownerpublicid` nach dem ersten Setzen unveränderbar. Die Toleranz auf etwa 5 Minuten senken. Direkte INSERT- und UPDATE-Rechte per Spaltenrechten einschränken.
- **Sicherheit:** verifiziert.

**B5 – mittel – Viele Tabellen haben keine Längen- oder Mengengrenzen**
- **Ort:**
  - `item_catalog`: name, brand, product_description, image_data, barcode.
  - `categories`: name, emoji, color_hex, icon.
  - `price_points`: item_key, item_name, store_name.
  - `profiles`: full_name, avatar_url und username ohne Obergrenze.
  - `list_invites`.
- **Beleg:** Die Constraint-Abfrage zeigt Grenzen nur auf `items`, auf `lists.title`, bei `username >= 3` und auf `image_path`. Es gibt keine Obergrenzen je Nutzer, weder für Listen noch für Artikel je Liste, Katalogeinträge, Preispunkte oder Storage-Objekte.
- **Szenario:** Ein einzelnes Konto füllt Datenbank und Storage. Bei 250.000 Nutzern wird so etwas zum Kostenrisiko und zu einem Weg, den Dienst lahmzulegen.
- **Empfehlung:** CHECK-Grenzen wie bei `items` ergänzen und zählende Obergrenzen einbauen, zum Beispiel per Trigger mit Zählung je Nutzer oder Liste.
- **Sicherheit:** verifiziert.

**B6 – mittel – Fehlende Fremdschlüssel hinterlassen verwaiste Daten**
- **Ort:** `lists.owner_id`, `categories.profile_id`, `item_catalog.owner_public_id` (Typ text) und `items.ownerpublicid`.
- **Beleg:** Die Tabelle `lists` hat nur Primärschlüssel und Titel-CHECK. Live gibt es 8 Kategorien, deren `profile_id` auf kein vorhandenes Profil mehr zeigt.
- **Szenario:** Wird ein Konto im Dashboard oder über die Admin-API gelöscht statt über `delete_my_account`, bleiben Listen, Artikel, Kategorien und Katalog stehen. Das ist ein DSGVO-Problem.
- **Empfehlung:** Fremdschlüssel mit `ON DELETE CASCADE` auf `profiles(id)` anlegen und `owner_public_id` auf den Typ uuid umstellen.
- **Sicherheit:** verifiziert.

**B7 – mittel – Die Migrationen lassen sich auf einer frischen Datenbank nicht nachbauen, und Live-Stand und Ordner weichen voneinander ab**
- **Ort:** `migrations/` und `list_migrations`.
- **Beleg:**
  - Das Grundschema fehlt im Ordner: `lists`, `items`, `profiles`, `list_members`, `categories`, `handle_new_user`, `set_updated_at`, `is_list_owner`, `is_list_member`, `gc_tombstones` und der Cron-Job.
  - Zehn Live-Migrationen haben keine Datei: `drop_website_column_from_profiles`, `create_kv_table_515802c7`, `fix_broadcast_changes_trigger_lists_table`, `drop_realtime_test_policy`, `fix_function_search_paths`, `add_fk_list_members_profiles_and_optimize_functions`, `tombstone_gc_cron`, `avatars_authenticated_read`, `018b_set_default_list_returns_boolean` und `add_hlc_columns_to_items`. Die letzte hat einen anderen Namen und ein anderes Datum als `001`.
  - `005_add_pagination_index.sql` wurde live **nie angewendet**. Die Indizes `items_list_created_id_idx` und `items_list_updated_idx` fehlen live. Das Präfix 005 ist doppelt vergeben, und die Reihenfolge der beiden 005-Dateien ist unbestimmt.
  - Die Indizes `idx_items_hlc` und `idx_items_tombstone` aus 001 fehlen live. Dafür existiert `idx_items_hlc_timestamp`, der in keiner Datei steht.
  - Mehrere Dateien sind nicht wiederholbar: 020 legt Constraints ohne Prüfung an, 019 legt `categories_*`-Policies ohne vorheriges DROP an, 002 und 004 legen Policies ohne Prüfung an. 013 greift auf `broadcast_changes_trigger` zu, das in keiner Datei angelegt wird.
  - Es gibt keine `supabase/`-Struktur für die CLI.
- **Szenario:** Staging, Disaster Recovery und Branching sind nicht möglich. Eine Abweichung zwischen Code und Live-Datenbank fällt niemandem auf.
- **Empfehlung:** Mit `supabase db pull` eine Basis-Migration erzeugen, auf die Struktur `supabase/migrations/<timestamp>_*.sql` umstellen und die Umgebung mit `supabase db reset` prüfen.
- **Sicherheit:** verifiziert.

**B8 – mittel – Der globale Produktkatalog ist direkt lesbar, damit lässt sich die Suchfunktion umgehen**
- **Ort:** Policy `global_catalog_select`.
- **Beleg:** Die Policy lautet `USING (true)`, und angemeldete Nutzer haben SELECT-Recht. Die Tabelle hat 227.121 Zeilen und bisher 411 sequenzielle Scans. Laut Kommentar in Migration 020 dauerte die ungebremste Suche 2,8 s im Mittel und bis zu 6,3 s.
- **Szenario:** Ein Nutzer fragt `GET /global_product_catalog?name_lower=ilike.*a*&order=scans_n.desc` wiederholt ab. So umgeht er die Mindestlänge von 3 Zeichen und das Limit von 300 Kandidaten in `search_global_products` und bindet Datenbankzeit bis zum Timeout von 8 s.
- **Empfehlung:** Das direkte SELECT-Recht entziehen und die Suche als SECURITY DEFINER nur über die Funktion anbieten.
- **Sicherheit:** plausibel. Ich habe keinen Lasttest gemacht.

**B9 – mittel – Der Tombstone-Löschlauf skaliert nicht**
- **Ort:** `gc_tombstones()` mit dem Cron-Ausdruck `0 3 * * *`.
- **Beleg:** `EXPLAIN` zeigt einen Seq Scan auf `items` mit Filter `tombstone AND updated_at < …`. Es gibt keinen passenden Index. Jede gelöschte Zeile löst `items_broadcast_trigger` aus und damit einen `realtime.send`-Aufruf.
- **Szenario:**
  - Bei vielen Millionen Artikeln durchsucht der Lauf jede Nacht die ganze Tabelle.
  - Er löscht alles in einer einzigen großen Transaktion und erzeugt dabei viel WAL.
  - Es entsteht eine Flut von Broadcast- und Postgres-Changes-Ereignissen.
  - Ein Gerät, das länger als 30 Tage offline war, kann bereits gelöschte Artikel wieder hochladen.
- **Empfehlung:** Einen Teilindex `(updated_at) WHERE tombstone` anlegen und in Stapeln mit `LIMIT` löschen. Beim Löschlauf keinen Broadcast senden, zum Beispiel über `pg_trigger_depth` oder ein Session-Flag. Außerdem eine Regel für den Resync nach 30 Tagen festlegen.
- **Sicherheit:** verifiziert.

**B10 – mittel – Einladungs-Tokens sind mehrfach nutzbar, und jedes Mitglied darf sie erzeugen**
- **Ort:** `create_list_invite`, `accept_list_invite`, `list_invites`.
- **Beleg:**
  - Die Tokens haben 192 Bit und sind damit nicht zu erraten. Das ist gut.
  - Sie liegen aber im **Klartext** als Primärschlüssel in der Tabelle.
  - Ein Token gilt 14 Tage für beliebig viele Beitritte.
  - `create_list_invite` prüft nur `has_list_access` und nicht, ob der Aufrufer der Besitzer ist.
  - Die Zahl der Mitglieder ist nicht begrenzt.
- **Szenario:**
  - Ein weitergeleiteter Link lässt beliebig viele Fremde beitreten.
  - Jeder, der Datenbank, Backup oder Logs lesen kann, erhält gültige Tokens.
  - Die Links kommen über das eigene URL-Schema `famlist://`. Eine andere App kann dieses Schema ebenfalls registrieren und den Token abfangen. Das ist plausibel und nicht getestet.
- **Empfehlung:** Nur den SHA-256-Hash des Tokens speichern und Einmal-Nutzung oder eine maximale Zahl von Beitritten einführen. Einladen optional nur dem Besitzer erlauben. Universal Links statt `famlist://` verwenden.
- **Sicherheit:** verifiziert, außer dem Abfangen über das URL-Schema.

**B11 – niedrig – Die anon-Rolle hat volle Tabellenrechte; allein RLS schützt**
- **Ort:** alle Tabellen in `public` außer `list_invites`.
- **Beleg:** `has_table_privilege('anon', …)` liefert für SELECT und INSERT überall `true`. Migration 020 hat nur die Standardrechte für künftige Objekte geändert.
- **Szenario:** Wird einmal eine Policy ohne `TO authenticated` angelegt, sind die Daten sofort ohne Anmeldung lesbar oder beschreibbar.
- **Empfehlung:** `REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon`.
- **Sicherheit:** verifiziert.

**B12 – niedrig – Das Profil verrät mehr als nötig, und `favorite_list_id` taugt als Existenz-Test**
- **Ort:** `profiles_select` und `profiles.favorite_list_id`.
- **Beleg:**
  - Mitglieder gemeinsamer Listen lesen alle Spalten fremder Profile, also auch `favorite_list_id`, `notify_*` und `avatar_url`.
  - Ein Nutzer darf `favorite_list_id` auf jede beliebige UUID setzen. Ob der Fremdschlüssel greift oder nicht, verrät, ob eine Liste mit dieser ID existiert.
- **Empfehlung:** Einen View oder Spaltenrechte für fremde Profile einführen und einen CHECK „nur zugängliche Listen“ per Trigger ergänzen.
- **Sicherheit:** verifiziert. Das Risiko ist gering, weil UUIDs praktisch nicht zu erraten sind.

**B13 – niedrig – Im Bucket item-images dürfen Mitglieder Fotos überschreiben, und die Dateien sammeln sich unbegrenzt an**
- **Ort:** Policies `item_images_update` und `item_images_insert`.
- **Beleg:** Die Policy prüft nur den ersten Ordner des Pfads. Der Dateiname „<sha256>.jpg“ wird serverseitig weder mit dem Inhalt abgeglichen noch per Muster erzwungen. UPDATE ist erlaubt. Es gibt keine DELETE-Policy, auch nicht für den Besitzer der Liste.
- **Szenario:**
  - Ein Mitglied ersetzt ein vorhandenes Foto durch anderen Inhalt; alle Mitglieder sehen dann das falsche Bild.
  - Ein Mitglied lädt beliebig viele Dateien mit bis zu 1 MB hoch.
  - Bestätigt ist außerdem der bekannte Punkt: `delete_my_account` löscht keine Fotos, und verwaiste Dateien im Storage bleiben liegen.
- **Empfehlung:** UPDATE verbieten, damit der Dateiname den Inhalt eindeutig kennzeichnet. Den Namen per Regex `^<uuid>/[0-9a-f]{64}\.jpg$` erzwingen. Einen serverseitigen Aufräumjob einrichten, zum Beispiel Edge Function oder Cron mit service_role.
- **Sicherheit:** verifiziert.

**B14 – niedrig – Die Avatar-Policies rufen `auth.uid()` ohne Zwischenspeicher auf, und signierte Links bleiben eine Stunde gültig**
- **Ort:** Policies `avatars_own_insert`, `avatars_own_update`, `avatars_own_delete` und `SupabaseProfilesRepository.swift:134` mit `expiresIn: 3600`.
- **Szenario:** Ein signierter Link funktioniert auch nach dem Entfernen aus der Liste noch bis zu 60 Minuten.
- **Empfehlung:** In den Policies `(select auth.uid())` verwenden und die Laufzeit der Links auf etwa 5 bis 10 Minuten senken.
- **Sicherheit:** verifiziert.

**B15 – niedrig – `handle_new_user` übernimmt vom Client gelieferte Metadaten ohne Grenze**
- **Ort:** `public.handle_new_user`.
- **Beleg:** Die Funktion schreibt `raw_user_meta_data->>'full_name'` und `->>'avatar_url'` ungeprüft in das Profil.
- **Szenario:** Bei der Registrierung setzt jemand eine beliebig lange Zeichenkette oder eine fremde URL. Diese erscheint dann in der Einladungs-Vorschau als Name des Einladenden.
- **Empfehlung:** Die Werte kürzen oder prüfen; `avatar_url` ignorieren.
- **Sicherheit:** verifiziert.

**B16 – niedrig (bekannt) – `is_username_available` ist unbegrenzt aufrufbar**
- **Beleg:** Es gibt kein Rate-Limit. Die Funktion verrät, ob ein Benutzername vergeben ist, und erlaubt so eine Aufzählung.
- **Empfehlung:** Ein Rate-Limit einbauen, zum Beispiel über eine Edge Function oder eine Zähltabelle je Nutzer.
- **Sicherheit:** verifiziert.

**B17 – niedrig (bekannt) – Entfernte Mitglieder empfangen Realtime bis zur Neuverbindung**
- **Beleg:** `list_topic_read` prüft `has_list_access` nur beim Beitritt zum Kanal.
- **Empfehlung:** Nach dem Ereignis `member_removed` den Kanal serverseitig kürzer autorisieren oder den Client zwingend neu verbinden lassen.
- **Sicherheit:** plausibel. Das Verhalten folgt aus der Supabase-Doku.

**B18 – niedrig – Das Privacy-Manifest fehlt**
- **Beleg:** Es gibt keine Datei `PrivacyInfo.xcprivacy` im Projekt. UserDefaults bzw. `@AppStorage` kommt in 23 Dateien vor, und das ist eine API mit Begründungspflicht.
- **Szenario:** App Store Connect meldet den Fehler ITMS-91053 oder lehnt den Upload ab.
- **Empfehlung:** Ein Manifest mit der Begründung CA92.1 für UserDefaults anlegen. Erfasste Daten angeben: E-Mail, Fotos, Nutzerinhalte.
- **Sicherheit:** Das Fehlen der Datei ist verifiziert. Die Folge im App Store ist plausibel.

**B19 – niedrig – Schlüssel und Testkonten**
- **Beleg:**
  - Der anon-Key steht versioniert in `Famlist/Info.plist` im öffentlichen Repo (`gh`: `PUBLIC`).
  - `Secrets.plist` war früher einmal eingecheckt (Commit 16fe77d) und wurde später gelöscht. Laut `git check-ignore` ist sie jetzt ignoriert.
  - Ich habe alle JWTs in der gesamten Git-Historie dekodiert. Es gibt nur einen, und dessen Rolle ist `anon`. Einen service_role-Key gibt es weder im Client noch in der Historie. `scripts/import_off_dach.py` liest den service_role-Key nur aus einer Umgebungsvariable.
  - Einen Ordner `.vscode/` gibt es nicht.
  - Laut Kommentar in `AuthTestHelpers.swift:22` standen alte Test-Passwörter im öffentlichen Repo und wurden live ersetzt. Das ist unverifiziert.
  - Die Live-Tests laufen gegen das **Produktivprojekt**.
- **Empfehlung:** Auf die neuen Publishable Keys umstellen, damit sich Schlüssel wechseln lassen. Die Test-Passwörter im Dashboard prüfen. Für Tests ein eigenes Projekt oder einen Branch nutzen.
- **Sicherheit:** verifiziert, außer dem Passwortwechsel.

**B20 – niedrig – Der Index für das seitenweise Laden fehlt live**
- **Ort:** `SupabaseItemsRepository.swift:197–202`.
- **Beleg:** Die Abfrage sortiert nach `created_at, id`, aber der Index `(list_id, created_at, id)` aus B7 fehlt. Postgres nutzt nur den ersten Teil von `idx_items_list_updated` und sortiert danach.
- **Szenario:** Bei sehr langen Listen steigt der Aufwand für jede Seite.
- **Empfehlung:** Den Index anlegen oder die Seiten nach `updated_at` laden.
- **Sicherheit:** verifiziert.

**B21 – Dashboard-Einstellungen (bekannt)**
- Leaked-Password-Schutz ist aus: verifiziert per Advisor.
- Für Postgres 17.4.1.074 gibt es Sicherheits-Patches: verifiziert per Advisor.
- Die JWT-Laufzeit lässt sich per SQL nicht prüfen und ist deshalb unverifiziert.

## Stärken

Diese Punkte habe ich geprüft und für gut befunden:

**Datenbank und RLS**
- Alle 9 Tabellen in `public` haben RLS aktiv. Jede Policy gilt nur `TO authenticated`.
- `list_invites` ist komplett gesperrt.
- `list_members` hat keine INSERT-Regel; ein Beitritt ist nur über den Token möglich.
- Die Hilfsfunktionen liegen im Schema `private`, und das ist für anon nicht nutzbar.
- Alle SECURITY-DEFINER-Funktionen haben einen festen `search_path`.
- Weder anon noch authenticated darf in `public` oder `private` Objekte anlegen, also ist der `search_path` nicht angreifbar.
- `accessible_list_ids()` ermittelt die erlaubten Listen einmal je Abfrage.
- Es gibt `statement_timeout`-Grenzen (anon 3 s, authenticated 8 s).
- pg_graphql ist nicht installiert.

**Realtime und Storage**
- Realtime läuft über private Broadcast-Kanäle.
- Es gibt keine INSERT-Policy auf `realtime.messages`, also können Clients nichts selbst senden.
- Alle Buckets sind privat und haben Größen- und MIME-Grenzen.

**App**
- Die Sitzung liegt im Keychain; das ist der Standard von supabase-swift 2.31.2 (`KeychainLocalStorage`).
- Der Login nutzt PKCE.
- Der URL-Cache ist abgeschaltet.
- Logs werden nur in Debug-Builds geschrieben.
- Es gibt keine ATS-Ausnahmen.

## Gesamteinschätzung

Die Zugriffsschicht ist nach den Migrationen 013 bis 020 solide. Es gibt keinen kritischen Befund und keinen Weg, als Außenstehender fremde Listen zu lesen oder zu beschreiben. Die größten Risiken betreffen Mitglieder, die schon Zugriff auf eine Liste haben: Sie können Artikel endgültig löschen, Base64-Daten schreiben und Felder fälschen, und das an der Upsert-Funktion vorbei (B2 bis B4). Hinzu kommt die übrig gebliebene Postgres-Changes-Publication (B1). Für 250.000 Nutzer fehlen vor allem Mengen- und Längengrenzen, ein Fremdschlüssel-Konzept und ein skalierbarer Tombstone-Löschlauf (B5, B6, B9). Unprofessionell ist vor allem die Migrationsgeschichte (B7): Die Live-Datenbank lässt sich aus dem Repo nicht nachbauen, und eine Migration wurde nie angewendet.

---

## Tests & Projekt-Setup (T)

# Audit: Tests, Build-Konfiguration und Projekt-Hygiene von Famlist

Stand ist der Branch `audit-fixes`, HEAD 7d54889. Ich habe nur gelesen und nichts geändert, nichts committet und keine Tests ausgeführt. Die Hilfsskripte liegen im Scratchpad unter `…/scratchpad/tests.py` und `coverage.tsv`.

## Kennzahlen

| Metrik | Wert | Messmethode |
|---|---|---|
| Unit-Tests | 560 XCTest-Funktionen und 20 `@Test` (Swift Testing, nur `ItemCategoryTests.swift`) | grep `func test…` und `@Test` in `Famlist/FamlistTests` |
| UI-Tests | 34 Funktionen in 8 Klassen (10 Dateien) | grep in `FamlistUITests` |
| Zeilen Testcode zu Produktionscode | 10.276 Unit plus 939 UI zu 33.516 in 333 Dateien, also etwa 0,33 | `wc -l` |
| Feste Wartezeiten, Unit | 24 feste Schlafpausen, dazu 11 Abfrage-Schleifen; `ListManagementTests` allein 15 × 100 ms | grep `Task.sleep` / `Thread.sleep`, jede Stelle einzeln gesichtet |
| Feste Wartezeiten, UI | 16 × `Thread.sleep` (0,3 bis 4 s), dazu 2 in Schleifen | wie oben |
| Tests ohne Assertion | 2 echte Fälle; ein dritter Treffer ist falsch-positiv | Python-Skript (Rumpf ohne `XCTAssert`/`#expect`/`XCTFail`/`waitForExistence`) |
| Tests über 60 Zeilen | 2, beide Live-Tests (111 und 63 Zeilen) | dasselbe Skript |
| Kernschicht-Typen ohne Nennung in Tests | 85 von 197 (viele davon sind Codable-Zeilentypen); 21 Dateien ganz ohne Nennung | Skript über `Core/Sync`, `Repositories`, `App`, `Features/*/ViewModels` und `Features/*/Services` |
| Test-Doubles | 18 Klassen; 6 Protokolle sind mehrfach nachgebaut; Preview-Repositories aus dem Produktionscode werden 45 × in Tests genutzt | grep `class …(Mock|Stub|Spy|Fake)` |
| Datenbank (SQL) | 21 Migrationen, 46 Policies, 21 Funktionen, 0 SQL-Tests | grep in `migrations/*.sql` |
| CI-Workflows | 0 | `.github/` enthält nur den leeren Ordner `prompts` |
| Swift-Einstellungen | Swift 6.0 und `SWIFT_STRICT_CONCURRENCY = complete` in allen Targets; Warnungen gelten nicht als Fehler | `project.pbxproj` |
| Mindest-iOS | App 17.0, UI-Tests 17.0, Unit-Tests 26.2 | `project.pbxproj` |
| `Package.resolved` eingecheckt? | nein | `git check-ignore` |
| `PrivacyInfo.xcprivacy` vorhanden? | nein | `find` |

## Befunde

**T1 – hoch – Die Paketversionen sind nicht festgeschrieben**
- Ort: `.gitignore:25` (`*.xcworkspace/`) und `project.pbxproj:2816-2818`.
- Beleg: `git check-ignore` zeigt, dass diese Regel `Famlist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` ausschließt. supabase-swift ist nur mit „ab 2.0.0 bis zur nächsten Hauptversion“ angegeben. Lokal ist 2.31.2 aufgelöst.
- Folge: Ein frischer Clone kann eine neuere 2.x-Version von supabase-swift oder seiner 6 Abhängigkeiten laden. Das ergibt nicht reproduzierbare Builds.
- Empfehlung: `!**/xcshareddata/swiftpm/Package.resolved` in `.gitignore` ergänzen und die Datei einchecken.
- Sicherheit: verifiziert.

**T2 – hoch – Es gibt kein Privacy-Manifest**
- Ort: Die Datei `PrivacyInfo.xcprivacy` fehlt im ganzen Projekt.
- Beleg: Die App nutzt `UserDefaults`, zum Beispiel in `PaginationCursor.swift:64` und `ListViewModel+Persistence.swift:121`. `UserDefaults` gehört zu Apples Liste der Schnittstellen, deren Nutzung begründet werden muss.
- Folge: App Store Connect lehnt einen Upload ohne diese Begründung ab oder warnt. Das weiß ich aus Apples Richtlinie seit Mai 2024; ich habe sie in dieser Sitzung nicht nachgelesen.
- Empfehlung: Ein Manifest anlegen, mindestens mit `NSPrivacyAccessedAPICategoryUserDefaults` und dem Grund CA92.1.
- Sicherheit: Das Fehlen ist verifiziert, die Folge ist plausibel.

**T3 – hoch – Es gibt kein CI, und der Testplan ist leer**
- Ort: `.github/` und `FamlistTestsPlan.xctestplan`.
- Beleg: Es gibt keinen Workflow. Der Testplan hat leere `defaultOptions`. Damit ist die Code-Abdeckung aus, die Reihenfolge ist fest, und im Plan ist keine Parallelisierung gesetzt. Das `parallelizable="YES"` im Scheme wird bei aktivem Testplan vermutlich ignoriert.
- Folge: Rund 614 Tests laufen nur, wenn jemand sie von Hand startet. Abhängigkeiten von der Reihenfolge der Tests bleiben unentdeckt, und die Abdeckung ist nicht messbar.
- Empfehlung: Einen GitHub-Actions-Job auf macOS anlegen, der die Unit-Tests ausführt. Im Testplan sollten `codeCoverage` und `testExecutionOrdering: random` eingeschaltet werden.
- Sicherheit: verifiziert.

**T4 – hoch – Die Datenbank-Regeln sind nicht getestet, und das Basisschema fehlt**
- Ort: `migrations/`.
- Beleg: Es gibt 46 Zugriffsregeln (`CREATE POLICY`) und 21 SQL-Funktionen, aber keinen pgTAP- oder anderen SQL-Test. Keine Migration legt `items`, `lists` oder `profiles` an; Migration 001 beginnt direkt mit `ALTER TABLE items`. Zwei Migrationen tragen die Nummer `005`. Nur `LiveRealtimeSharingTests` ruft 3 Funktionen auf (`create_list_invite`, `accept_list_invite`, `upsert_items_lww`) und prüft, dass Nicht-Mitglieder keine Realtime-Ereignisse erhalten. Dieser Test läuft nur mit `FAMLIST_LIVE=1`.
- Folge: Ein Fehler in den Zugriffsregeln fällt erst im Betrieb auf. Die Datenbank lässt sich aus dem Repo nicht neu aufbauen.
- Empfehlung: Das Basisschema per `supabase db dump` versionieren. Danach pgTAP-Tests schreiben: Nicht-Mitglied darf nicht lesen, schreiben oder löschen; ungültiger Einladungs-Token wird abgelehnt; `delete_my_account` funktioniert. Die doppelte Nummer 005 auflösen.
- Sicherheit: verifiziert.

**T5 – hoch – `SyncOrchestrator` und `PageLoader` haben keinen einzigen Test**
- Ort: `Core/Sync/SyncOrchestrator.swift` (120 Zeilen) und `Core/Sync/PageLoader.swift` (72 Zeilen).
- Beleg: Keine Testdatei nennt die beiden Typen. Der Orchestrator sammelt Realtime-Ereignisse, während Seiten geladen werden, und fasst sie pro Artikel zusammen. Laut seinem Dateikopf verwirft er ab 200 gepufferten Ereignissen alle wartenden.
- Folge: Das ist der Schutz gegen Wettläufe zwischen Seitenladen und Realtime. Ein Fehler dort lässt Änderungen still verschwinden.
- Empfehlung: Unit-Tests schreiben für: UPDATE gewinnt, DELETE entfernt, Grenze bei 200 Ereignissen, Puffer wird nach dem Laden abgearbeitet.
- Sicherheit: verifiziert.

**T6 – mittel – Die Sync-Warteschlange hat keine eigene Testdatei**
- Ort: `Core/Sync/OperationQueue.swift` (`SyncOperationQueue`).
- Beleg: Die Klasse hat 20 Funktionen. Tests rufen nur 3 davon direkt auf (`peek`, `resetRetryDelays`, `resetFailedOperation`). Das Ersetzen wartender Operationen in `enqueue`, die Regel „höchstens eine Operation je Artikel“ in `dequeueBatch` und der Zustand „in Arbeit“ laufen nur indirekt über `SyncEngine`.
- Folge: Regressionen in der Warteschlange sind schwer einer Ursache zuzuordnen.
- Empfehlung: Eine Datei `SyncOperationQueueTests` mit einem Speicher-Container pro Test anlegen.
- Sicherheit: plausibel. Die indirekte Abdeckung habe ich nicht vollständig nachverfolgt.

**T7 – mittel – `SyncErrorClassifier` ist nur teilweise getestet**
- Ort: `SyncErrorClassifier.swift:33-76`.
- Beleg: Direkt geprüft wird nur der Zweig für `StorageError` (`Audit2SyncTests.swift:104-106`). Die Zweige für `URLError` und `HTTPError` laufen je einmal indirekt (`SyncEngineReactivationTests.swift:172,188`). Die Zuordnung der Postgres-Codes (`PGRST3…`, `08…`, `53…`, `57…`, `40001`, `40P01`) und der Fall „Status 401 gilt als vorübergehend“ sind ungetestet.
- Folge: Wenn ein Fehler falsch eingestuft wird, bleibt eine Änderung für immer hängen oder wird endlos wiederholt.
- Empfehlung: Einen tabellengetriebenen Test über alle Zweige schreiben.
- Sicherheit: verifiziert.

**T8 – mittel – Abmelden und Konto löschen haben keine Unit-Tests**
- Ort: `AppSessionViewModel+SignOut.swift:24-60` und `AppSessionViewModel+Account.swift:158`.
- Beleg: `signOut(discardingUnsentChanges:)`, `sendPendingChanges()` und `deleteAccount` werden in keinem Unit-Test aufgerufen. Die Rückfrage vor dem Abmelden aus dem letzten Commit prüft nur ein Live-UI-Test, und der wird ohne `FAMLIST_LIVE` übersprungen. `sendPendingChanges` liest `ConnectivityMonitor.shared` fest ein; dort gibt es keinen Ersatzpunkt für Tests.
- Folge: Genau hier drohen Datenverlust (lokale Daten werden gelöscht) und das Löschen des Kontos, ohne dass automatisch getestet wird.
- Empfehlung: Den Online-Status injizierbar machen. Dann testen: Abmelden wird bei ungesendeten Änderungen blockiert, mit Bestätigung verworfen, und der lokale Zustand wird zurückgesetzt.
- Sicherheit: verifiziert.

**T9 – mittel – Tests und Test-App teilen sich einen SwiftData-Container**
- Ort: `PersistenceController.swift:25`, `FamlistApp.swift:46-50,137-144` und `ListManagementTests.swift:25,112,189,402`.
- Beleg: `preview` ist ein einziges `static let`, das pro Prozess einmal entsteht. Die App, in der die Unit-Tests laufen, nutzt genau diesen Container, und zwar mit einem `ListViewModel` mit `startImmediately: true`. 8 Tests in 3 Dateien arbeiten ebenfalls darauf: `ListManagementTests`, `ListViewModelMembershipEvictionTests` und `ItemCatalogTests`. Der Kommentar in `ListManagementTests.swift:25` nennt den Container fälschlich „isolated“.
- Folge: Die CLAUDE.md verlangt einen Reset pro Test; das ist hier verletzt. Daten bleiben zwischen Tests liegen, und das Ergebnis kann von der Reihenfolge abhängen. Die anderen 26 Dateien legen korrekt eigene Speicher-Container an.
- Empfehlung: In Tests immer `PersistenceController(inMemory: true)` oder einen eigenen `ModelContainer` pro Test verwenden.
- Sicherheit: verifiziert.

**T10 – mittel – `ListViewModel` schreibt ohne Injektion in `UserDefaults.standard`**
- Ort: `ListViewModel+Persistence.swift:121-136`, `ListViewModel+Reconcile.swift:34-40` und `PaginationCursor.swift:64-82`.
- Beleg: Dort gibt es keinen Parameter für die Einstellungs-Ablage. Die Tests laufen in der App mit der Bundle-ID `com.roxo.famlist`.
- Folge: Tests schreiben in die echten Einstellungen der Simulator-App, zum Beispiel die 25-Tage-Sperre für den Abgleich. Zufällige Listen-IDs machen Kollisionen selten, schließen sie aber nicht aus. Die Tests selbst nutzen vorbildlich eigene Einstellungs-Bereiche (`suiteName`).
- Empfehlung: `defaults` injizierbar machen, wie es bei `ListSortSettings` und `PriceBook` schon der Fall ist.
- Sicherheit: plausibel.

**T11 – mittel – Feste Wartezeiten und fest eingebaute Zeitdauern**
- Ort: `ListManagementTests.swift` (15 Stellen, zum Beispiel Zeilen 150 und 167), `RemoteSyncHighlightTests.swift:110-113`, `ListViewModelUndoDeleteTests.swift:105` und `PendingItemDeletion.swift:31`.
- Beleg:
  - `ListManagementTests` wartet 15-mal 100 ms und prüft danach.
  - Der Highlight-Test hat bei einer Lebensdauer von 2 s nur 0,2 s bzw. 0,3 s Puffer.
  - Der Undo-Test schläft volle 5 s, weil `undoDuration` fest eingebaut ist.
  - Die UI-Tests enthalten 16 × `Thread.sleep`, zum Beispiel `SwipeUITests.swift` 5 × 1 s.
- Folge: Auf langsamen Rechnern werden diese Tests rot, auf schnellen dauern sie unnötig lang.
- Empfehlung: Den vorhandenen Helfer `waitUntil` nutzen. Für Zeitdauern eine Uhr oder Dauer injizierbar machen. In UI-Tests `waitForExistence` bzw. Warten auf ein Prädikat verwenden.
- Sicherheit: verifiziert.

**T12 – niedrig – Der Warte-Helfer ist mehrfach kopiert**
- Ort: `TestWaiting.swift` und je ein privates `waitUntil` in `OfflineListsRepositoryTests:88`, `OfflineItemCatalogRepositoryTests:83`, `AccountAndSharingTests:67`, `ManageItemsAndBarcodeTests:61` und `CategoryStoreTests:56`.
- Beleg: Die privaten Kopien verdecken den gemeinsamen Helfer. Sie geben nach 2 s still auf. Dazu kommen die eigenen Varianten `waitForItems` und `waitFor`.
- Empfehlung: Einen gemeinsamen Helfer behalten, der bei Zeitüberschreitung `XCTFail` mit Beschreibung auslöst.
- Sicherheit: verifiziert.

**T13 – mittel – Test-Doubles sind dupliziert, und es gibt keinen gemeinsamen Test-Support-Ordner**
- Beleg:
  - `ListsRepository` ist 3-mal nachgebaut: `MockListsRepository`, `StubLists`, `FakeRemoteLists`.
  - `ItemCatalogRepository`, `GlobalProductCatalogRepository`, `SyncEngineProtocol`, `ItemsRepository` und `ProfilesRepository` sind je 2-mal nachgebaut.
  - `MockAuthClient` und `MockSupabaseClient…` gibt es je 2-mal.
  - Außerdem dienen die Preview-Repositories aus dem Produktionscode 45-mal als Test-Double, `PreviewItemsRepository` allein 28-mal.
- Folge: Jede Änderung an einem Protokoll erfordert Änderungen an vielen Stellen. Eine Änderung an einem Vorschau-Repository ändert das Verhalten von Tests.
- Empfehlung: Einen Ordner `FamlistTests/Support/` mit je einem konfigurierbaren Fake pro Protokoll anlegen.
- Sicherheit: verifiziert.

**T14 – mittel – Die Unit-Tests verlangen iOS 26.2, die App nur iOS 17.0**
- Ort: Die Test-Konfigurationen im `project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 26.2`).
- Beleg: Das Target entstand in Commit c34700d am 8. März 2026. Die Tests nutzen keine iOS-26-Schnittstelle; ein grep nach `@available` und nach iOS-26-Symbolen findet nichts. Der Wert 26.2 ist daher sehr wahrscheinlich die Xcode-Vorgabe beim Anlegen des Targets. Zusätzlich hat nur das Test-Target `SWIFT_APPROACHABLE_CONCURRENCY` und `MEMBER_IMPORT_VISIBILITY` eingeschaltet.
- Folge: Die Zweige für iOS 17 hinter `#available(iOS 18.0, *)` werden nie getestet (`ShoppingListView.swift:193`, `HorizontalPanGesture.swift:44`). Build und Test brauchen zwei verschiedene Simulatoren.
- Empfehlung: Das Test-Target auf 17.0 setzen und die Einstellungen an die App angleichen.
- Sicherheit: Die Werte sind verifiziert, die Ursache ist plausibel.

**T15 – niedrig – Warnungen gelten nicht als Fehler**
- Ort: `project.pbxproj`.
- Beleg: `SWIFT_TREAT_WARNINGS_AS_ERRORS` fehlt, `GCC_TREAT_WARNINGS_AS_ERRORS` ebenfalls.
- Folge: Neue Warnungen zur Nebenläufigkeit (Concurrency) können sich still ansammeln.
- Empfehlung: Die Einstellung mindestens im CI setzen.
- Sicherheit: verifiziert.

**T16 – mittel – Die Server-Konfiguration steht fest in `Info.plist`, und es gibt keine getrennte Testumgebung**
- Ort: `Famlist/Info.plist` (Schlüssel `SUPABASE_URL` und `SUPABASE_ANON_KEY`) und `SupabaseClient.swift:43-63`.
- Beleg: Der Loader prüft `Info.plist` vor `Secrets.plist`. Der `Secrets.plist`-Pfad ist damit praktisch toter Code. Sein Kommentar und die CLAUDE.md beschreiben es falsch. Der Anon-Key ist öffentlich gedacht, das ist also kein Geheimnis-Leck.
- Folge: Live-Tests und Live-UI-Tests schreiben in dieselbe Datenbank wie die ausgelieferte App.
- Empfehlung: Eine xcconfig-Datei pro Konfiguration anlegen und ein eigenes Supabase-Projekt oder einen Branch für Tests nutzen. Kommentar und Doku korrigieren.
- Sicherheit: Die Konfiguration ist verifiziert. Dass es keine Testumgebung gibt, ist plausibel.

**T17 – mittel – Die App ist auch für iPad freigegeben**
- Ort: App-Target, `TARGETED_DEVICE_FAMILY = "1,2"`.
- Beleg: Das Design gilt nur für ein iPhone mit 390 × 844 pt. Auf dem iPad ist nur Hochformat erlaubt, mit `UIRequiresFullScreen`.
- Folge: Der App Store verlangt iPad-Screenshots, und das iPad-Layout ist ungetestet.
- Empfehlung: Auf `1` (nur iPhone) setzen, falls das iPad nicht gewollt ist.
- Sicherheit: Die Einstellung ist verifiziert, die Folge ist plausibel.

**T18 – niedrig – Der Kamera-Hinweis ist nur deutsch**
- Ort: `INFOPLIST_KEY_NSCameraUsageDescription`.
- Beleg: Der Text ist deutsch und vorhanden. Als Entwicklungssprache ist aber `en` eingestellt, und es gibt keine `InfoPlist.xcstrings`. Ein Hinweis für die Fotobibliothek ist nicht nötig, weil nur `PhotosPicker` und `UIImagePickerController` zum Auswählen genutzt werden.
- Empfehlung: `developmentRegion` auf `de` setzen oder den Text lokalisieren.
- Sicherheit: verifiziert.

**T19 – niedrig – Die Versionsnummern werden nie erhöht**
- Beleg: Alle Targets stehen auf `MARKETING_VERSION = 1.0` und `CURRENT_PROJECT_VERSION = 1`. Es gibt keine Automatik, die sie erhöht.
- Folge: Ein zweiter Upload zu TestFlight scheitert, solange die Build-Nummer gleich bleibt.
- Sicherheit: verifiziert.

**T20 – mittel – Die Projekt-CLAUDE.md ist nicht versioniert und veraltet**
- Ort: Die Datei heißt `claude.md` und wird von `.gitignore:48` ignoriert. Weil `core.ignorecase=true` gilt, trifft die Regel auch `CLAUDE.md`. Es ist nur eine Datei: beide Namen haben dieselbe Inode 216064373.
- Beleg:
  - Die erste Zeile ist ein Chat-Rest: „Hier ist deine maßgeschneiderte …“.
  - Sie spricht von „~86 Swift-Dateien“; tatsächlich sind es 333.
  - Sie sagt, `SyncMonitor` sei „noch NICHT integriert“. Tatsächlich nimmt `SyncEngine.swift:63,86` ihn entgegen, und es gibt `SyncMonitorIntegrationTests`.
  - Es gibt kein README. `TECHNICAL_DOCUMENTATION.md` existiert lokal gar nicht mehr, obwohl das Memory sie noch als vorhanden führt.
  - Die Kopfzeile von `.gitignore` nennt noch „GroceryGenius“.
- Folge: Ein anderer Clone oder Agent bekommt die Projektregeln nicht.
- Empfehlung: Die Datei als `CLAUDE.md` versionieren, den Chat-Rest und die veralteten Angaben entfernen und ein kurzes README anlegen.
- Sicherheit: verifiziert.

**T21 – niedrig – Die Session-Handoffs sind uneinheitlich eingecheckt**
- Beleg: 3 Handoffs aus `.claude/handoffs` sind eingecheckt, 2 sind es nicht. `.claude/agent-memory` ist ebenfalls eingecheckt.
- Positiv: `Secrets.plist`, `.DS_Store` und `xcuserdata` sind korrekt ignoriert und nicht eingecheckt. `Secrets.plist` war früher 7-mal in der Historie, enthielt aber nur URL und Anon-Key.
- Empfehlung: Festlegen, ob Handoffs ins Repo gehören.
- Sicherheit: verifiziert.

**T22 – niedrig – Die ausgelieferte App schreibt gar keine Logs**
- Ort: `Logger.swift:117-160` und `UserLogger.swift`.
- Beleg: Beide Systeme geben nur per `print` aus, und nur in Debug-Builds (`#if DEBUG`). `os.Logger` wird nicht genutzt. Die Schwärzung sensibler Werte in Debug prüft nur die Schlüsselnamen; verschachtelte Werte und Fehlertexte bleiben ungefiltert. Die Regel „`UserLog` nur in ViewModels“ ist eingehalten: 46 Aufrufe liegen in `ViewModels/` und 21 im `AppSessionViewModel`.
- Folge: Die Release-Version ist datensparsam, aber Probleme bei Nutzern lassen sich nicht nachvollziehen.
- Empfehlung: `os.Logger` mit `privacy: .private` für Fehlerereignisse einsetzen.
- Sicherheit: verifiziert.

**T23 – niedrig – Zwei Tests prüfen nichts Eigenes**
- Beleg:
  - `DuplicateAddUITests.swift:45` ruft nur einen anderen Test auf. Dessen Assertions stehen dort, aber dieser Test läuft dadurch doppelt.
  - `ScreenTourUITests.swift:60` fotografiert nur und vergleicht nichts automatisch. Der Dateikopf behauptet aber, damit werde „geprüft“.
  - Der dritte Treffer, `LiveRealtimeSharingTests:279`, prüft doch: sein `waitFor` löst `XCTFail` aus.
- Sicherheit: verifiziert.

**T24 – niedrig – Größe und Struktur der Testdateien**
- Beleg:
  - `ItemCatalogTests.swift` hat 629 Zeilen und 5 Testklassen.
  - `ListManagementTests.swift` hat 519 Zeilen, 6 Klassen und einen Mock in derselben Datei.
  - `ClipboardImportParserTests.swift` hat 566 Zeilen.
  - Die Namen sind gemischt: 544 Tests im Stil `test_…`, 50 im Stil `testCamelCase`.
  - `FamlistTests.swift` ist leer.
- Sicherheit: verifiziert.

**T25 – niedrig – Die Test-Hooks sind sauber vom Release getrennt**
- Das ist eine positive Feststellung.
- Beleg:
  - `UITestFixture.swift` und `ShoppingListView+DesignLaunch.swift` stehen komplett unter `#if DEBUG`.
  - `SimulatedOffline` liefert in Release immer `false`.
  - `AuthTestHelpers.swift` ist nur mit `DEBUG` und im Simulator aktiv.
  - `ListViewModel+TestSeeding.swift` gehört nur zum Test-Target; das habe ich über die Source-Build-Phase geprüft.
- Einschränkung: Die Preview-Repositories und `PreviewSyncEngine` sind auch im Release-Build enthalten. Das ist gewollt, weil sie als Rückfall dienen, wenn die Konfiguration fehlt. Da `Info.plist` die Konfiguration immer liefert, wird dieser Rückfall nie genutzt.
- Sicherheit: verifiziert.

## Gesamteinschätzung

Die Testbasis ist für ein Einzelprojekt groß und inhaltlich stark:
- Es gibt gezielte Tests für die Zeitstempel-Uhr (HLC), den Konfliktabgleich „letzter Schreiber gewinnt“ über mehrere Geräte, den Realtime-Schutz vor Überschreiben wartender Änderungen, die Offline-Repositories mit Temp-Ordnern und Import-, Kassenzettel- und Preislogik.
- Die meisten Dateien legen pro Test einen eigenen Speicher-Container und eigene Einstellungs-Bereiche an.
- Swift 6 mit vollständiger Nebenläufigkeitsprüfung ist in allen Targets aktiv.
- Die Test-Hooks sind sauber mit `#if DEBUG` vom Release getrennt.

Die größten Lücken liegen außerhalb des Testcodes:
- Es gibt kein CI, keine Abdeckungsmessung und keine SQL-Tests für 46 Zugriffsregeln. Das Datenbank-Basisschema fehlt im Repo.
- `Package.resolved` ist nicht eingecheckt, und ein Privacy-Manifest fehlt. Das erschwert reproduzierbare Builds und blockiert voraussichtlich den App-Store-Upload.

Im Testcode selbst sind die ungetesteten Sync-Bausteine `SyncOrchestrator` und `PageLoader` am dringendsten. Danach folgen der geteilte Container `PersistenceController.preview` und die festen Wartezeiten in `ListManagementTests`.

---

## Fehlerbehandlung & Robustheit (R)

# Robustheits-Audit Famlist (Branch audit-fixes, HEAD 7d54889)

Ich habe keine Projektdatei geändert. Meine Hilfsskripte liegen nur im Scratchpad. Geprüft habe ich die 333 Swift-Dateien unter `Famlist/`, ohne FamlistTests und UI-Tests.

## Kennzahlen

| Kennzahl | Wert | Messmethode |
|---|---|---|
| `try?` gesamt | 118 | Python-Regex `(?<![A-Za-z_])try\?`, Kommentarzeilen ausgenommen. Ein einfaches grep hätte 128 gezählt, weil es auch „Retry?“ und „entry?“ trifft. |
| davon `Task.sleep` (harmlos) | 23 | |
| davon SwiftData lesen/schreiben | 34 | Einordnung nach Schlüsselwort |
| davon Netzwerk/async | 19 | |
| davon JSON (Codable) | 18 | |
| davon Dateisystem 9, Regex 6, Kamera 4, Fotoauswahl 3, Sonstiges 2 | 24 | |
| `try!` | 0 | |
| `catch`-Blöcke gesamt | 77 | Skript |
| leere `catch {}` | 0 | Skript |
| `catch`, der nur loggt | 26 | Das Skript fand 19. Bei der Sichtprüfung kamen 7 hinzu, deren Log-Aufruf über mehrere Zeilen geht. |
| `localizedDescription` im UI | 0 | Alle 47 Treffer stehen in Debug-Logs oder im Feld `lastErrorMessage`. Dieses Feld zeigt keine View an (grep). |
| Nutzung von `UserFacingError` | 6 Stellen | AppSession: Auth und DeepLink. ListViewModel: `setError`. Andere ViewModels verwenden eigene feste Sätze. |
| `UserLog` außerhalb von ViewModels | 0 | grep. `CategoryStore` und `PriceBook` liegen im Ordner ViewModels. |
| `UserLog.Error` genutzt | 2 Stellen | grep |
| Logs im Release-Build | keine | `Logger.swift` und `UserLog.isEnabled` sind mit `#if DEBUG` abgesichert. Es gibt kein `os_log` und kein `NSLog`. |
| Privacy Manifest (`.xcprivacy`) | fehlt | `find` und pbxproj-grep: 0 Treffer |

## Befunde

**R1 – hoch – Wer auf einem anderen Gerät abgemeldet wird, bleibt „angemeldet“ und bekommt keinen Hinweis**
- Ort: `Core/Networking/SupabaseClient.swift:212-214` und `App/AuthService.swift:109`
- Beleg: `for await ev in authClient.authStateChanges { logVoid(params: ["authEvent": …]) }`. Abmelden läuft über `signOut(scope: .global)`.
- Szenario:
  - Robert meldet sich auf dem iPad ab. Das beendet die Sitzungen aller Geräte.
  - Das iPhone zeigt weiter seine Listen an. Jede Änderung geht nun ohne Anmeldung an den Server. Der Server bricht mit Fehlercode 42501 ab.
  - `SyncErrorClassifier` stuft diesen Code als dauerhaften Fehler ein. Deshalb werden alle Artikel als „Sync fehlgeschlagen“ markiert.
  - Die App zeigt nie den vorhandenen Satz `UserFacingError.sessionExpired`.
  - Dasselbe gilt, wenn das Konto auf einem anderen Gerät gelöscht wurde.
- Empfehlung: Auf `.signedOut` und `.userDeleted` reagieren. Die App soll dann zur Anmeldung wechseln, einen Hinweis zeigen und die Warteschlange behalten. Den Fehler 42501 „not authenticated“ soll die App als abgelaufene Anmeldung einordnen.
- Sicherheit: Der App-Code ist verifiziert. Dass das SDK beim gescheiterten Token-Refresh ein `signedOut`-Ereignis sendet, ist plausibel, aber nicht geprüft.

**R2 – hoch – Absturz beim Import aus der Zwischenablage, wenn eine Zahl sehr groß ist**
- Ort: `ClipboardImportParser+Units.swift:142,145`, `+Quantity.swift:123` und `ImportMergeService.swift:111,144`
- Beleg: `max(1, Int((quantity - 0.0001).rounded(.up)))`. Die Regex erlaubt beliebig viele Ziffern (`\d+`).
- Szenario: Robert fügt „99999999999999999999 Eier“ ein. Ich habe genau diese Rechnung mit Swift 6.3 ausgeführt. Ergebnis: `Fatal error: Double value cannot be converted to Int because the result would be greater than Int.max`.
- Empfehlung: Die Menge vor der Umwandlung auf 1…9999 begrenzen. Außerdem die Regex auf höchstens 4 Ziffern beschränken.
- Sicherheit: verifiziert (Codelauf).

**R3 – hoch – Lässt sich die Datenbank nicht öffnen, gehen ungesendete Offline-Änderungen still verloren**
- Ort: `Core/Storage/PersistenceController.swift:46-50, 57-83`
- Beleg: Bei jedem Fehler von `ModelContainer(...)` ruft die App `moveAside(configuration.url)` auf und legt eine neue, leere Datenbank an.
- Szenario:
  - Nach einem App-Update scheitert die Schema-Migration. Oder das Öffnen scheitert, weil der Speicher voll ist.
  - Die Warteschlange `SyncOperation` liegt in der beiseitegelegten Datei. Alles, was offline erfasst und noch nicht gesendet wurde, ist damit weg.
  - Die App meldet das nicht.
  - Die `.broken-*`-Kopien löscht die App nie, auch nicht beim Abmelden oder Löschen des Kontos. Sie belegen Speicher und enthalten fremde Kontodaten.
- Empfehlung: Den Nutzer informieren. Offene Operationen aus der alten Datei retten oder zumindest zählen. `.broken`-Dateien beim Abmelden und nach einer Frist löschen.
- Sicherheit: Der Code ist verifiziert. Das Szenario ist plausibel.

**R4 – mittel – Jede Bearbeitung eines Artikels mit Foto lädt das Foto neu hoch und hinterlässt die alte Datei im Storage**
- Ort: `ItemFormViewModel.swift:86,130` und `SyncEngine+LocalChanges.swift:85`
- Beleg:
  - Beim Öffnen macht die App aus Base64 ein `UIImage`. Beim Speichern kodiert sie es mit `ProductImageCodec.encode` neu.
  - Danach gilt `existing?.imageData != item.imageData` als wahr. Die Engine setzt deshalb `imageChanged = true`.
- Test: Ich habe ein JPEG mit Qualität 0,72 dreimal nacheinander neu kodiert. Keine Generation war byte-gleich (83310 → 80556 → 79707 → 79342 Byte).
- Folge:
  - Ändert Robert nur die Menge, lädt die App trotzdem ein neues Foto hoch. Es bekommt einen neuen SHA-Pfad.
  - Die alte Datei bleibt im Storage liegen. Die App ruft `storageRemove` nur für Avatare auf.
  - Das Foto verliert mit jeder Bearbeitung an Qualität.
- Empfehlung: Das Foto nur neu kodieren, wenn der Nutzer ein neues Bild gewählt hat. Sonst die vorhandenen `imageData` unverändert übernehmen.
- Sicherheit: Der Code ist verifiziert. Den JPEG-Test habe ich auf macOS mit ImageIO gemacht. Dass iOS sich genauso verhält, ist plausibel.

**R5 – mittel – Die App kennt die Längen- und Wertgrenzen des Servers nicht; abgelehnte Daten verschwinden still oder bleiben dauerhaft „fehlgeschlagen“**
- Serverseitige Grenzen:
  - Listentitel: 1–100 Zeichen (`018_lists_integrity.sql:20`)
  - Artikel (`020_scale_and_hardening.sql:91-100`): Name höchstens 200 Zeichen, Beschreibung höchstens 500, `units` höchstens 1.000.000, Preis unter 1.000.000
- In der App gibt es keine dieser Grenzen (grep nach `prefix` und `count` in Sheets und Validator).
- Szenario 1 – langer Listentitel:
  - Robert gibt einer Liste einen Titel mit 120 Zeichen. `OfflineListsRepository.swift:173-183` stuft die Ablehnung als dauerhaft ein und verwirft die Anlage mit `store.removeFirst()`.
  - Die Liste existiert danach nur auf dem Gerät. Artikel darin scheitern am Server, weil es die Liste dort nicht gibt.
- Szenario 2 – langer Artikelname: Ein Name mit 250 Zeichen führt zu `invalid`. „Erneut synchronisieren“ scheitert dann jedes Mal, und die App erklärt nicht, warum.
- Empfehlung: Die Grenzen zentral in `ItemInputValidator` festlegen und in allen Eingabefeldern durchsetzen. Auch der Import muss sie einhalten.
- Sicherheit: Grenzen und Verwerfen sind verifiziert. Der Fremdschlüssel-Fehler im Szenario ist plausibel.

**R6 – mittel – Mehrere Fehlermeldungen setzt die App, zeigt sie aber nie an**
- Ort:
  - `AppSessionViewModel+Account.swift:72` (Favorit), `:123` (Foto), `:150` (Benachrichtigungen)
  - `+DeepLink.swift:29` (ungültiger Einladungslink bei angemeldetem Nutzer)
  - `CategoryStore.swift:203`
- Beleg: `session.errorMessage` beobachten nur `SignInView`, `AcceptInviteView` und der Dialog „Konto löschen“. `categoryStore.errorMessage` liest keine View (grep).
- Szenario: Der Foto-Upload scheitert. Das Bild springt still zurück, und Robert erfährt nicht, warum.
- Empfehlung: Einen globalen Toast für `session.errorMessage` in `ShoppingListView` einbauen, ebenso für den `CategoryStore`.
- Sicherheit: verifiziert.

**R7 – mittel – Das Kaufdatum von Preisen verschiebt sich in Deutschland um einen Tag nach hinten**
- Ort: `ReceiptParser.swift:128` und `SupabasePricePointsRepository.swift:33,54`
- Beleg: Der Parser setzt Mitternacht in lokaler Zeit. Die App speichert das Datum dann mit einem Formatierer in UTC (`yyyy-MM-dd`).
- Szenario 1: Ein Bon vom 25.09. 00:00 Sommerzeit entspricht 24.09. 22:00 UTC. Die App speichert also „2026-09-24“.
- Szenario 2: Ein Bon vom 01.10. landet in der September-Statistik.
- Szenario 3: Ein manuell erfasster Preis zwischen 0 und 2 Uhr bekommt ebenfalls das Datum des Vortags.
- Empfehlung: Denselben Kalender mit derselben Zeitzone für das Parsen und das Formatieren verwenden. Einfacher ist es, den Kalendertag als `DateComponents` zu übergeben.
- Sicherheit: verifiziert.

**R8 – mittel – Die Katalog-Warteschlange verwirft Änderungen nach 5 Fehlversuchen**
- Ort: `OfflineItemCatalogRepository.swift:146-153`
- Beleg: Nur `URLError` gilt als offline. Alle anderen Fehler zählen als Fehlversuch, auch 401 und 5xx. Nach `maxFailures` folgt `store.removeFirst()`.
- Szenario:
  - `search`, `find(barcode:)` und `fetchAll` rufen alle zuerst `flush()` auf.
  - Bei abgelaufener Anmeldung (R1) oder einer Serverstörung genügen deshalb fünf Suchen. Dann ist ein neuer oder geänderter Katalogartikel still gelöscht.
- Empfehlung: `SyncErrorClassifier` verwenden, wie es `OfflineListsRepository` schon tut. Vorübergehende Fehler sollen nicht zählen.
- Sicherheit: verifiziert.

**R9 – mittel – Keine Hilfe, wenn der Kamerazugriff verweigert ist**
- Ort: `ReceiptCaptureView.swift:119-129` und `BarcodeScanSheet.swift:89`
- Beleg: Die App zeigt nur „Kamera nicht verfügbar“ mit Deckkraft 0,25. Der Text ist mit `accessibilityHidden(true)` vor VoiceOver versteckt.
- Nach `openSettingsURLString` findet grep 0 Treffer. Die App unterscheidet also nicht zwischen „verweigert“ und „keine Kamera“ und bietet keinen Weg in die Einstellungen.
- Weitere stille Kamerafehler:
  - `ReceiptCamera.swift:43` schluckt einen Fehler von `AVCaptureDeviceInput` mit `try?`. `start()` meldet trotzdem `true`.
  - `BarcodeCameraView.swift:45` schluckt `startScanning()` mit `try?`.
  - In beiden Fällen sieht Robert nur ein schwarzes Bild und einen Auslöser ohne Wirkung.
- Empfehlung: Den Berechtigungsstatus auswerten. Einen gut lesbaren Hinweis mit Knopf „Einstellungen öffnen“ zeigen.
- Sicherheit: verifiziert.

**R10 – mittel – Möglicher Absturz beim Schalten der Taschenlampe**
- Ort: `ReceiptCamera.swift:72-77` und `BarcodeCameraView.swift:61-67`
- Beleg: Die App setzt `try? device.lockForConfiguration()`, danach `device.torchMode = …` und dann `unlockForConfiguration()`.
- Szenario: Die Sperre scheitert, zum Beispiel weil ein anderer Prozess die Kamera belegt. Oder die Lampe ist wegen Überhitzung gesperrt (`isTorchAvailable == false`). Das Setzen ohne Sperre löst laut Apple eine Ausnahme aus.
- Empfehlung: `do/catch` verwenden, `isTorchAvailable` prüfen und nur nach erfolgreicher Sperre schalten.
- Sicherheit: plausibel (Apple-Vorgabe, nicht am Gerät reproduziert).

**R11 – mittel – Das Privacy Manifest fehlt**
- Beleg: Es gibt kein `PrivacyInfo.xcprivacy`, und die pbxproj enthält 0 Treffer dafür. Die App nutzt UserDefaults vielfach (PriceBook, CategoryStore, ProfileCache, Cursor).
- Folge: UserDefaults gehört zu Apples „Required Reason APIs“. Nach Apples Regeln seit Mai 2024 beanstandet App Store Connect einen Upload ohne Begründung.
- Empfehlung: Ein Manifest mit `NSPrivacyAccessedAPICategoryUserDefaults` (Grund CA92.1) anlegen und die erfassten Datentypen deklarieren.
- Sicherheit: Das Fehlen ist verifiziert. Die Folge stammt aus Apples Regeln.

**R12 – mittel – Das Profilfoto ist dreimal so groß wie gedacht, und die Verarbeitung erzeugt Speicherspitzen**
- Ort: `AppSessionViewModel+Account.swift:180-190`, `EditProfileSheet.swift:150` und `ProfileSetupView.swift:138`
- Beleg: `UIGraphicsImageRenderer(size: target)` verwendet ohne eigenes Format den Bildschirmfaktor. Auf einem 3×-iPhone entsteht deshalb ein Bild mit 1536 × 1536 px statt 512 × 512 px. `ProductImageCodec` setzt dagegen korrekt `format.scale = 1`.
- Zusätzlich dekodiert `UIImage(data:)` ein 48-MP-Foto in voller Größe. Das sind rund 190 MB im Arbeitsspeicher.
- Empfehlung: `format.scale = 1` setzen. Das Foto über `CGImageSourceCreateThumbnailAtIndex` verkleinert laden.
- Sicherheit: Der Code ist verifiziert. Die Pixelgröße folgt aus Apples Dokumentation.

**R13 – mittel – Scheitert das lokale Speichern, merkt Robert es nicht**
- Ort: `SyncEngine+LocalChanges.swift:92-94` und `SyncEngine.swift:280-287` (`saveStore`)
- Beleg: `catch { logVoid(params: (action: "write.error", …)) }`. `saveStore` loggt ebenfalls nur.
- Szenario:
  - Der Gerätespeicher ist voll. Der Artikel steht im Arbeitsspeicher und wird angezeigt.
  - Die App wird beendet, und der Artikel ist weg.
  - Die App gibt keinen Hinweis, auch kein `UserLog`.
- Empfehlung: Fehler als Rückgabewert an das ViewModel melden und dort `setError` aufrufen.
- Sicherheit: Der Code ist verifiziert. Das Szenario ist plausibel.

**R14 – niedrig bis mittel – Der Fehler beim Anmeldelink rät immer „Prüfe deine Verbindung“**
- Ort: `AppSessionViewModel+Onboarding.swift:48`
- Szenario: Supabase begrenzt die Zahl der Anmelde-E-Mails. Bei dieser Sperre sagt die App trotzdem, Robert solle die Verbindung prüfen. `UserFacingError.rateLimited` gibt es, die App nutzt es hier aber nicht.
- Empfehlung: `UserFacingError.message(for:)` verwenden.
- Sicherheit: verifiziert.

**R15 – niedrig bis mittel – Scheitert das Laden eines ausgewählten Fotos, erfährt Robert es nicht**
- Ort: `ReceiptCaptureView.swift:213`, `EditProfileSheet.swift:150` und `ProfileSetupView.swift:138`. Alle nutzen `try? await item.loadTransferable`.
- Szenario:
  - Robert wählt ohne Netz Fotos, die nur in iCloud liegen. Nichts passiert.
  - Beim Kassenzettel ruft die App trotzdem `onContinue()` auf. `process()` bricht bei leeren Seiten sofort ab (`ReceiptFlowViewModel.swift:65`).
  - Das Prüf-Blatt bleibt leer und zeigt keine Meldung.
- Sicherheit: verifiziert.

**R16 – niedrig bis mittel – Liste verschwindet, während sie offen ist**
- Entzug der Mitgliedschaft: Die App schaltet Robert ohne Hinweis auf eine andere Liste um. Es gibt nur ein UserLog, das im Release-Build abgeschaltet ist (`ListViewModel+RealtimeSync.swift:232-251`).
- Eigene Liste auf einem anderen Gerät gelöscht:
  - Besitzer stehen nicht in `list_members`. Einträge dort legt nur `accept_list_invite` an (`014:122`).
  - Das zweite Gerät des Besitzers erhält deshalb kein `member_removed`.
  - `loadAllLists` (`ListViewModel+ListManagement.swift:36-60`) räumt weder lokale Daten auf noch schließt es die aktive Liste.
- Empfehlung: Einen Hinweis-Toast zeigen. Beim Laden der Listen verschwundene Listen erkennen und bereinigen.
- Sicherheit: Der Hinweis-Teil ist verifiziert. Der Teil zum Besitzer-Gerät ist plausibel.

**R17 – niedrig bis mittel – Kassenzettel-Seiten belegen viel Speicher**
- Ort: `ReceiptFlowViewModel.swift:33,60`
- Die Zahl der Seiten ist unbegrenzt. Jede Seite ist ein `UIImage` in voller Auflösung. Die Seiten bleiben nach der Erkennung im Speicher, bis der Ablauf endet.
- Sicherheit: plausibel.

**R18 – niedrig – Benachrichtigungen lassen sich einschalten, kommen aber nie an**
- Ort: `AppSessionViewModel+Account.swift:138-153`
- Beleg: Die App fragt die Systemberechtigung ab. Es gibt aber kein `registerForRemoteNotifications`, und die Entitlements enthalten nur Sign in with Apple, kein `aps-environment`. Eine Ablehnung der Berechtigung wertet die App nicht aus.
- Sicherheit: verifiziert.

**R19 – niedrig – Scheitert die Barcode-Suche, meldet die App „unbekannt“**
- Ort: `BarcodeScanViewModel.swift:62-66`
- Szenario: Die Suche scheitert, weil kein Netz da ist oder der Server einen Fehler meldet. Die App zeigt dann „unbekannt“ und bietet an, den Artikel neu anzulegen. So entstehen Duplikate.
- Eine eigene Prüfung der EAN-Prüfziffer gibt es nicht (grep 0 Treffer). Ich verlasse mich darauf, dass VisionKit die Prüfziffer prüft; das habe ich nicht verifiziert.
- Sicherheit: Der Code ist verifiziert.

**R20 – niedrig – Die Zwischenablage wird automatisch gelesen**
- Ort: `ClipboardImportSheet.swift:65` (`onAppear(perform: viewModel.load)`)
- Das Blatt liest die Zwischenablage selbst per Code. iOS fragt dann jedes Mal nach der Erlaubnis zum Einfügen. Tippt Robert „Nicht erlauben“, meldet die App fälschlich „Zwischenablage leer“.
- Empfehlung: `PasteButton` verwenden.
- Zusätzlich landet der Einladungslink samt Token ohne `localOnly` und ohne Ablaufzeit in der allgemeinen Zwischenablage (`ShareMembersSheet.swift:231`). Er wird damit auch an andere Apple-Geräte weitergegeben.
- Sicherheit: plausibel.

**R21 – niedrig – Der Katalog-Cache ist groß und wird ins Backup übernommen**
- Ort: `CatalogLocalStore.swift:46-58` und `OfflineItemCatalogRepository.swift:66-71`
- Der Cache ist eine einzige JSON-Datei mit Base64-Fotos in Application Support.
- Die App schreibt die Datei bei jedem `fetchAll` komplett neu, synchron auf dem Main Actor.
- Die Datei ist nicht vom iCloud-Backup ausgeschlossen (`isExcludedFromBackup`: 0 Treffer).
- Sicherheit: verifiziert.

**R22 – niedrig – Die Preis-Warteschlange in UserDefaults hat keine Obergrenze**
- Ort: `PriceBook.swift:48-54, 82-88`
- Warteschlange und Verlaufs-Cache wachsen ohne Grenze.
- Scheitert das Dekodieren, verwirft `try?` die ganze Warteschlange ohne Hinweis.
- Sicherheit: verifiziert.

**R23 – niedrig – Die Regel für Nutzer-Logs ist lückenhaft erfüllt**
- `UserLog.Error` wird nur zweimal verwendet.
- Diese Fehlerpfade haben kein UserLog: Profil, Foto, Favorit, Konto löschen, Mitglied entfernen, Liste umbenennen, Liste löschen und Katalog-Speichern.
- `ClipboardImportViewModel` und `ItemSearchViewModel` enthalten gar kein UserLog.
- Sicherheit: verifiziert.

**R24 – bekannt, bestätigt**
- Fotos liegen als Base64 in SwiftData und werden auf dem Main Actor verarbeitet:
  - `ItemImagePrefetcher` ist `@MainActor` und schreibt `imageData` als Base64 (Zeilen 24 und 58-61).
  - `refreshItemsFromStore` liest bei jeder Änderung alle Artikel der Liste samt Base64 neu ein. Das trifft Listen mit 1.000 und mehr Artikeln stark.
- Storage-Waisen bei Kontolöschung: `SupabaseProfilesRepository.swift:137-143` löscht nur `avatars/…/avatar.jpg`. `item-images` und `catalog-images` bleiben liegen.

**Verworfen nach Nachprüfung:**
- Rohe Fehlertexte im UI: Es gibt keine.
- Division durch 0 bei Preisstatistik, Fortschritt und Preis je Einheit: Alle Stellen sind abgesichert.
- Doppelt gesendete Preispunkte: Das Upsert mit `ignoreDuplicates` verhindert sie.
- Timer und Observer ohne Abmeldung: Alle haben `[weak self]` oder werden abgebrochen.
- Logs mit Tokens oder E-Mails im Release-Build: Alle Logs sind im Release-Build abgeschaltet.

## Gesamteinschätzung

Die Fehlerbehandlung ist deutlich besser als üblich. Es gibt keine leeren `catch`-Blöcke und kein `try!`. Kein roher Fehlertext erreicht die Oberfläche. Beide Logsysteme sind im Release-Build abgeschaltet, und die Sync-Engine unterscheidet sauber zwischen offline, vorübergehenden und dauerhaften Fehlern. Die größten Risiken liegen an den Rändern:
- die fehlende Reaktion auf Abmelde-Ereignisse (R1)
- ein reproduzierbarer Absturz beim Import (R2)
- stiller Datenverlust bei Datenbankfehlern, bei abgelehnten Eingaben und in der Katalog-Warteschlange (R3, R5, R8)
- Fehlermeldungen, die gesetzt, aber nie angezeigt werden (R6)

Außerdem schränkt das fehlende Privacy Manifest die Veröffentlichung ein (R11). Ich empfehle, zuerst R1 und R2 zu beheben, dann R3, R5 und R8.

Zum Nachprüfen nach Korrekturen würde ich die Unit-Tests laufen lassen: `xcodebuild test -project Famlist.xcodeproj -scheme Famlist -destination 'platform=iOS Simulator,id=F1ECDBCC-15DC-4E12-8B57-9A6D5073B1AF' -only-testing:FamlistTests`. Dazu kämen Tests mit sehr großen Mengen für `ClipboardImportParserTests` und mit Zeitzonen für `SupabasePricePointsRepository`.
