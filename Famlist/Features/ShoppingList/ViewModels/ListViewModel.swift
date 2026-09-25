// MARK: - ListViewModel.swift

/*
 ListViewModel.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Core ViewModel for shopping list screens. Manages state, dependencies, and basic CRUD operations.
 - Refactored into focused extensions for better maintainability (see ListViewModel+*.swift files).

 🛠 Includes:
 - Core State (@Published properties)
 - Dependencies (repositories, stores)
 - Lifecycle (init, deinit)
 - Configuration methods
 - Basic CRUD operations (add, update, delete, toggle)

 🔰 Notes for Beginners:
 - This is the main class definition. Additional functionality is in extension files.
 - Repository abstraction enables mocking in tests.
 - @Published drives SwiftUI diffing automatically.
 - All public methods are @MainActor-only for thread safety.

 📝 Last Change:
 - Refactored into smaller focused files per coding guidelines (<300 lines each).
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID, DispatchSemaphore, and base types used here.
import SwiftUI // SwiftUI is needed for ObservableObject and @Published used by the view model.
import Combine // Combine provides AnyCancellable used for connectivity monitoring.

/// ViewModel encapsulating shopping list state and repository synchronization.
@MainActor // Guarantees that all state changes happen on the main thread (UI thread).
final class ListViewModel: ObservableObject { // ObservableObject lets SwiftUI observe changes to @Published properties.
    
    // MARK: - Published State
    
    /// The items currently displayed in the UI. Changes re-render views.
    @Published var items: [ItemModel] = []

    /// Legacy selection state (the Hybrid UI passes the item to EditItemSheet directly).
    @Published var selectedItem: ItemModel?

    /// Optional error message surfaced to the UI on operation failures.
    @Published var errorMessage: String?

    /// Indicates when the view is performing a long-running action.
    @Published var isLoading: Bool = false

    /// The resolved default list for the current user; nil while loading.
    @Published var defaultList: ListModel? = nil

    /// All lists belonging to the current user; populated by loadAllLists(ownerId:).
    @Published var allLists: [ListModel] = []

    /// Item counts per list id, sourced from the local SwiftData store.
    @Published var listItemCounts: [UUID: Int] = [:]

    /// Active tab filter ("Alle · Offen · Erledigt"). Display-only state, never persisted or synced.
    @Published var itemFilter: ItemFilter = .all

    /// Sortier-Einstellung der aktiven Liste (Dock „Sortieren“), lokal pro Liste gespeichert.
    @Published var sortSettings: ListSortSettings = .default

    /// Kategorien des Nutzers in Ladenweg-Reihenfolge (CategoryStore); steuert „Nach Kategorie“.
    @Published var categoryOrder: [CategoryDefinition] = CategoryDefinition.defaults

    /// Manuelle Reihenfolge der aktiven Liste (Artikel-IDs), lokal pro Liste gespeichert.
    @Published var manualOrder: [String] = []

    /// Mitglieder der aktiven Liste ohne Eigentümer (für ☰ „Mitglieder & Teilen“ und das Teilen-Sheet).
    @Published var activeListMembers: [ListMember] = []

    /// Gelöschte Artikel, die noch per „Rückgängig“ zurückgeholt werden können (Toast, 5 s).
    @Published var pendingDeletion: PendingItemDeletion?

    /// Neue ID, sobald der Nutzer den letzten offenen Artikel abhakt (→ „Einkauf erledigt“ anbieten).
    /// Nur Nutzeraktionen setzen sie – kein Listenwechsel, kein Realtime-Update anderer Mitglieder.
    @Published var shoppingCompletedEvent: UUID?

    /// Läuft ab, sobald der Rückgängig-Toast ausgeblendet wird; schreibt dann die Löschung.
    internal var pendingDeletionTask: Task<Void, Never>?

    // MARK: - Pagination State (FAM-40)

    /// True when more remote pages might be available for the current list.
    /// Reset to true on Pull-to-Refresh and Sign-Out.
    @Published var hasMoreItems: Bool = true

    /// True while a remote page fetch is in progress (drives loading indicator).
    @Published var isLoadingNextPage: Bool = false

    /// Composite cursor pointing to the last loaded remote item.
    /// Nil triggers loading from the first page. Cleared on Pull-to-Refresh and Sign-Out.
    var currentCursor: PaginationCursor? = nil

    /// Consecutive empty-page counter for the T3 termination rule:
    /// after 1 empty page following a full page, hasMoreItems is set to false.
    var consecutiveEmptyPages: Int = 0
    
    // MARK: - Dependencies & Core State
    
    /// Abstraction over the data source (Supabase or in-memory preview).
    internal let repository: ItemsRepository
    
    /// Central sync engine for CRDT-based operations.
    /// Always non-nil at runtime: production uses `SyncEngine`, previews use `PreviewSyncEngine`.
    internal var syncEngine: (any SyncEngineProtocol)?
    
    /// Current list context; switching replaces the observed stream of items.
    private(set) var listId: UUID {
        didSet { loadListPreferences() }
    }
    
    /// Optional ListsRepository used to resolve default list (injected post-init to keep compatibility).
    internal var listsRepository: ListsRepository?

    /// Optional personal item catalog repository; injected after init via configure(catalogRepository:).
    /// When set, new items are automatically saved to the catalog in the background.
    internal var catalogRepository: (any ItemCatalogRepository)?

    /// Optional global OpenFoodFacts catalog repository; injected after init via configure(globalCatalogRepository:).
    /// When set, ItemSearchView will show global OFF products alongside personal catalog results.
    internal var globalCatalogRepository: (any GlobalProductCatalogRepository)?
    
    /// Local SwiftData store for offline persistence.
    internal let itemStore: SwiftDataItemStore
    
    /// Local SwiftData store for list metadata.
    internal let listStore: SwiftDataListStore
    
    /// Holds the background task that observes live item changes.
    internal var observeTask: Task<Void, Never>?

    /// Beobachtet list_members DELETE-Events für den eingeloggten User.
    internal var membershipTask: Task<Void, Never>?
    
    /// Retains connectivity subscription so it lives with the view model.
    private var connectivityCancellable: AnyCancellable?

    /// Tracks whether realtime observation has started at least once.
    internal var hasObservedActiveList: Bool = false

    /// Sync orchestrator used by loadNextPage() to serialise page fetches with Realtime events.
    internal var syncOrchestrator: SyncOrchestrator?

    /// Page loader responsible for remote cursor-based pagination.
    internal var pageLoader: PageLoader?
    
    /// Item identifiers that currently have an optimistic reorder animation in flight.
    /// While they remain here, we keep the local ordering authoritative to avoid jitter.
    internal var pendingAnimatedItemIDs: Set<String> = []

    /// IDs of items freshly applied from a remote source (Realtime event or IncrementalSync delta).
    /// Drives the one-shot sync-highlight animation in ListRowView.
    /// Entries are removed automatically after 2 seconds via markRecentlySynced(ids:).
    /// Never populated by local mutations — only by the Realtime stream handler and runIncrementalSync().
    @Published var recentlySyncedItemIDs: Set<String> = []

    /// Suppresses `refreshItemsFromStore()` during the synchronous forEach phase of bulk-delete.
    /// Prevents per-item SwiftData refreshes from re-rendering the list one item at a time.
    internal var isBulkDeleting = false

    /// True while a bulk operation (import or delete-all) is mutating SwiftData.
    /// While active, the stream handler, Realtime refreshes, and pagination are suppressed
    /// so the UI only sees the final stable state (before-bulk or after-bulk), never an intermediate.
    internal var isBulkMutationActive = false

    /// IDs of items currently undergoing a bulk delete operation.
    /// Populated before deletion starts; cleared lazily as items are confirmed removed from SwiftData.
    /// Guards against Realtime snapshots or async SyncEngine callbacks reinstating items
    /// that have been deleted from the UI but are not yet purged from the remote.
    internal var pendingBulkDeleteIDs: Set<String> = []
    
    /// Debounce task for bulk toggle operations to prevent rapid repeated calls.
    internal var toggleAllDebounceTask: Task<Void, Never>?

    /// Laufender Delta-Abgleich; wird beim Listenwechsel abgebrochen.
    internal var incrementalSyncTask: Task<Void, Never>?

    /// Listen, für die in dieser Sitzung schon Fotos aus dem Artikelstamm übernommen wurden.
    internal var backfilledListIDs: Set<UUID> = []

    /// Lädt Fotos anderer Geräte sofort herunter (offline verfügbar). nil ohne Storage (Vorschau/Tests).
    internal var imagePrefetcher: ItemImagePrefetcher?
    
    /// Enumerates triggers that can resume realtime sync to aid logging and debugging.
    internal enum ResumeTrigger: String {
        case appForeground
        case connectivity
    }
    
    // MARK: - Lifecycle
    
    /// Creates a ListViewModel with a target list and a repository (defaults to preview repo for development/previews).
    /// - Parameters:
    ///   - listId: Initial list identifier to scope observations to.
    ///   - repository: ItemsRepository implementation for data access.
    ///   - itemStore: SwiftData store for items.
    ///   - listStore: SwiftData store for lists.
    ///   - startImmediately: Whether to start observing items immediately (set false until auth ready).
    init(
        listId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
        repository: ItemsRepository,
        itemStore: SwiftDataItemStore,
        listStore: SwiftDataListStore,
        startImmediately: Bool = true
    ) {
        self.listId = listId // Store which list we are managing.
        self.repository = repository // Store the data source implementation.
        self.itemStore = itemStore
        self.listStore = listStore
        loadListPreferences()
        if startImmediately {
            startObserving() // Begin listening for item updates only when requested.
        }
    }
    
    deinit {
        observeTask?.cancel() // Cancel observation task to prevent dangling realtime streams.
        connectivityCancellable?.cancel() // Stop listening to connectivity changes when the view model deallocates.
    }
    
    // MARK: - Configuration
    
    /// Injects a ListsRepository used to fetch/create the user's default list.
    /// - Parameter listsRepository: Concrete implementation (Supabase or Preview) resolving default list rows.
    func configure(listsRepository: ListsRepository) {
        self.listsRepository = listsRepository
    }
    
    /// Injects the connectivity monitor so the view model can resume realtime sync when the device comes back online.
    /// - Parameter connectivityMonitor: Shared monitor publishing online/offline state.
    func configure(connectivityMonitor: ConnectivityMonitor) {
        connectivityCancellable?.cancel() // Cancel previous subscription if configure gets called again.
        connectivityCancellable = connectivityMonitor.$isOnline
            .removeDuplicates()
            .sink { [weak self] isOnline in
                guard let self else { return }
                if isOnline {
                    self.prefetchImages()
                    self.resumeRealtimeSync(trigger: .connectivity)
                    // Also resume sync engine if available
                    Task {
                        await self.syncEngine?.resumeSync()
                    }
                }
            }
    }
    
    /// Injects the sync engine for CRDT-based operations.
    /// Pass `SyncEngine` in production, `PreviewSyncEngine` in previews.
    func configure(syncEngine: any SyncEngineProtocol) {
        self.syncEngine = syncEngine
        // Offline-First: nach jedem lokalen Schreiben sofort aus SwiftData neu lesen (nicht erst nach dem Netzwerk).
        syncEngine.setLocalWriteObserver { [weak self] in self?.refreshItemsFromStore() }
        // Nutzer-Logs zum Sync entstehen hier im ViewModel (Projektregel), nicht in der SyncEngine.
        syncEngine.setSyncEventObserver { event in
            switch event {
            case .started(let count):
                if count > 0 { UserLog.Sync.syncing(itemCount: count) }
            case .completed(let count, _):
                if count > 0 { UserLog.Sync.completed(itemCount: count) }
            case .itemFailed(let item):
                UserLog.Sync.itemSyncFailed(name: item.name, units: item.units, measure: item.measure)
            }
        }
    }

    /// Fotos in Supabase Storage (Migration 016): Herunterladen für die Offline-Anzeige.
    func configure(imageStorage: ImageStorage) {
        imagePrefetcher = ItemImagePrefetcher(store: itemStore, storage: imageStorage) { [weak self] in
            self?.refreshItemsFromStore()
        }
    }

    /// Fehlende Fotos im Hintergrund laden (alle Listen).
    internal func prefetchImages() {
        guard let imagePrefetcher else { return }
        Task { await imagePrefetcher.prefetchMissing() }
    }

    /// Injects the personal item catalog repository for smart search support.
    /// - Parameter catalogRepository: Repository that saves/searches the user's item catalog.
    func configure(catalogRepository: any ItemCatalogRepository) {
        self.catalogRepository = catalogRepository
    }

    /// Injects the global OpenFoodFacts catalog repository for extended product search.
    /// - Parameter globalCatalogRepository: Read-only repository for the global OFF DACH catalog.
    func configure(globalCatalogRepository: any GlobalProductCatalogRepository) {
        self.globalCatalogRepository = globalCatalogRepository
    }

    /// Injects the SyncOrchestrator and PageLoader for cursor-based pagination (FAM-79/FAM-40).
    func configure(syncOrchestrator: SyncOrchestrator, pageLoader: PageLoader) {
        self.syncOrchestrator = syncOrchestrator
        self.pageLoader = pageLoader
        syncOrchestrator.onBudgetExceeded = { [weak self] in
            guard let self else { return }
            Task { await self.runIncrementalSync() }
        }
    }
    
    // MARK: - List Switching
    
    /// Switches the active list; cancels current observation and starts a new one for the new list id.
    func switchList(to newId: UUID) {
        guard newId != self.listId else { return }
        commitPendingDeletion()              // offene Rückgängig-Löschung der alten Liste festschreiben
        observeTask?.cancel()
        incrementalSyncTask?.cancel()
        toggleAllDebounceTask?.cancel()
        self.listId = newId
        self.items = []
        recentlySyncedItemIDs = []
        pendingBulkDeleteIDs = []
        pendingAnimatedItemIDs = []
        // Reset pagination state for the new list (cursor is loaded from UserDefaults per listId in startObserving).
        currentCursor = PaginationCursor.load(listId: newId)
        hasMoreItems = true
        isLoadingNextPage = false
        consecutiveEmptyPages = 0
        startObserving()
    }
    
    /// Clears view model state in response to sign-out.
    func clearForSignOut() {
        commitPendingDeletion()
        observeTask?.cancel()
        observeTask = nil
        incrementalSyncTask?.cancel()
        incrementalSyncTask = nil
        toggleAllDebounceTask?.cancel()
        toggleAllDebounceTask = nil
        membershipTask?.cancel()
        membershipTask = nil
        pendingBulkDeleteIDs = []
        pendingAnimatedItemIDs = []
        backfilledListIDs = []
        syncEngine?.resetForSignOut()                 // Warteschlange gehört zum abgemeldeten Konto
        items = []
        recentlySyncedItemIDs = []
        selectedItem = nil
        defaultList = nil
        allLists = []
        listItemCounts = [:]
        itemFilter = .all
        errorMessage = nil
        // Reset pagination state and clear persisted cursor/timestamp.
        PaginationCursor.clear(listId: listId)
        clearLastSyncTimestamp()
        (catalogRepository as? OfflineItemCatalogRepository)?.clearLocalData()   // Artikelstamm des Kontos
        currentCursor = nil
        hasMoreItems = true
        isLoadingNextPage = false
        consecutiveEmptyPages = 0
        listId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        refreshItemsFromStore()
        hasObservedActiveList = false
        ListViewModel.currentSortOrder = .category
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new item after normalizing fields (e.g., measure, listId).
    /// - Parameter barcode: EAN/UPC aus dem Barcode-Scanner; wird im Artikelstamm gemerkt.
    func addItem(_ item: ItemModel, barcode: String? = nil) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString

        // Duplikat-Check: existiert bereits ein ungehacktes Item mit gleichem Namen?
        if let existingIndex = items.firstIndex(where: {
            ItemIdentity.normalizedKey($0.name) == ItemIdentity.normalizedKey(normalized.name) && !$0.isChecked
        }) {
            incrementExisting(at: existingIndex, with: normalized)
            return
        }

        // Endgültige ID sofort bestimmen – die sofort angezeigte Karte und der gespeicherte Artikel
        // haben dieselbe ID (vorher: Zufalls-ID, später ersetzt → doppelte Einträge möglich).
        if let listUUID = UUID(uuidString: normalized.listId ?? "") {
            normalized = normalized.withId(ItemIdentity.newItemId(name: normalized.name, listId: listUUID, store: itemStore).uuidString)
        }

        let displayName = [normalized.brand, normalized.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        UserLog.Data.itemAdded(
            name: displayName.isEmpty ? "Artikel" : displayName,
            units: normalized.units,
            measure: normalized.measure
        )

        saveToCatalog(normalized, barcode: barcode)

        // Gerade weggewischt und noch im Rückgängig-Zeitraum? Dann erst die Löschung festschreiben und
        // danach neu anlegen – beides in dieser Reihenfolge, damit das Anlegen die neuere HLC bekommt.
        // Vorher verschwand der neu hinzugefügte Artikel nach 5 s wieder (Audit H2).
        let pendingDeleteTask = pendingBulkDeleteIDs.contains(normalized.id) ? commitPendingDeletion() : nil

        items.append(normalized)                 // Sofort sichtbar (Offline-First)

        guard let syncEngine else { return }
        let toCreate = normalized
        Task {
            await pendingDeleteTask?.value
            await syncEngine.createItem(toCreate)
            self.refreshItemsFromStore()
        }
    }

    /// Duplikat hinzugefügt: Menge des vorhandenen Artikels erhöhen und fehlende Angaben ergänzen.
    private func incrementExisting(at index: Int, with added: ItemModel) {
        var incremented = items[index]
        let oldUnits = incremented.units
        incremented.units = oldUnits + max(added.units, 1)
        incremented = ListViewModel.fillingMissingFields(of: incremented, from: added)
        logVoid(params: (action: "addItem.increment", itemId: incremented.id, from: oldUnits, to: incremented.units))
        UserLog.Data.itemCountIncremented(name: incremented.name, from: oldUnits, to: incremented.units,
                                          measure: incremented.measure)
        items[index] = incremented
        updateItem(incremented, suppressUserLog: true)
    }

    /// Artikelstamm im Hintergrund ergänzen (blockiert die Liste nicht).
    private func saveToCatalog(_ item: ItemModel, barcode: String?) {
        guard let catalogRepo = catalogRepository else { return }
        var catalogEntry = ItemCatalogEntry.from(item: item, ownerPublicId: "")
        catalogEntry.barcode = barcode
        Task {
            do {
                try await catalogRepo.save(catalogEntry)
            } catch {
                logVoid(params: (action: "catalogSave.failed", itemName: item.name, error: (error as NSError).localizedDescription))
            }
        }
    }
    
    /// Updates an existing item after normalizing fields.
    /// - Parameter suppressUserLog: Pass `true` when the caller has already logged the action
    ///   (e.g. `toggleItemChecked`, increment path in `addItem`) to avoid duplicate logs.
    /// - Parameter updateCatalog: false, wenn die Änderung aus dem Artikelstamm kommt (dort schon gespeichert).
    func updateItem(_ item: ItemModel, trackPendingAnimation: Bool = false, suppressUserLog: Bool = false,
                    updateCatalog: Bool = true) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString

        // Umbenennen: Die ID hängt am Namen. Alten Artikel löschen, neuen anlegen (ADR-005) – sonst würde
        // späteres Hinzufügen des alten Namens den umbenannten Artikel überschreiben (Audit H3).
        if let old = currentItem(id: normalized.id),
           ItemIdentity.normalizedKey(old.name) != ItemIdentity.normalizedKey(normalized.name) {
            renameItem(from: old, to: normalized, updateCatalog: updateCatalog)
            return
        }

        logVoid(params: (
            action: "updateItem",
            itemId: normalized.id,
            brand: normalized.brand ?? "nil",
            category: normalized.category ?? "nil",
            description: normalized.productDescription ?? "nil"
        ))

        if !suppressUserLog {
            let displayName = [normalized.brand, normalized.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let resolvedName = displayName.isEmpty ? "Artikel" : displayName
            // Detect quantity change by comparing with current items snapshot (still holds old state at call time).
            if let oldItem = items.first(where: { $0.id == normalized.id }), oldItem.units != normalized.units {
                UserLog.Data.itemQuantityChanged(
                    name: resolvedName,
                    from: oldItem.units,
                    to: normalized.units,
                    measure: normalized.measure
                )
            } else {
                UserLog.Data.itemUpdated(name: resolvedName)
            }
        }

        // Update personal item catalog (fire-and-forget; keeps catalog in sync with edits)
        if updateCatalog, let catalogRepo = catalogRepository {
            let catalogEntry = ItemCatalogEntry.from(item: normalized, ownerPublicId: "")
            Task {
                do {
                    try await catalogRepo.save(catalogEntry)
                    logVoid(params: (action: "catalogUpdate.success", itemName: normalized.name))
                } catch {
                    logVoid(params: (action: "catalogUpdate.failed", itemName: normalized.name, error: (error as NSError).localizedDescription))
                }
            }
        }

        // Offline-First: Bearbeitung sofort in `items` sichtbar machen. Vorher kam die Änderung erst
        // nach `syncEngine.updateItem` (inkl. Netzwerk-Queue) über refreshItemsFromStore an – bei langsamer
        // oder fehlender Verbindung zeigte „Artikel bearbeiten“ deshalb weiter den alten Preis (0,00).
        applyLocalEdit(normalized)

        // Track animation state if requested.
        if trackPendingAnimation {
            pendingAnimatedItemIDs.insert(normalized.id)
        }
        
        guard let syncEngine else {
            if trackPendingAnimation { pendingAnimatedItemIDs.remove(normalized.id) }
            return
        }
        Task {
            await syncEngine.updateItem(normalized)
            await MainActor.run {
                // Refresh UI from SwiftData so the edit (e.g. price change) is immediately visible
                // without waiting for a Realtime echo. storeLocally() already wrote the correct
                // value; this call propagates it to self.items.
                self.refreshItemsFromStore()
                if trackPendingAnimation {
                    self.pendingAnimatedItemIDs.remove(normalized.id)
                }
            }
        }
    }
    
    /// Übernimmt die bearbeitbaren Felder sofort in `items`; CRDT-/Sync-Felder bleiben unverändert.
    private func applyLocalEdit(_ edited: ItemModel) {
        guard let index = items.firstIndex(where: { $0.id == edited.id }) else { return }
        var current = items[index]
        current.name = edited.name
        current.units = edited.units
        current.measure = edited.measure
        current.price = edited.price
        current.isChecked = edited.isChecked
        current.isUnavailable = edited.isUnavailable
        current.category = edited.category
        current.productDescription = edited.productDescription
        current.brand = edited.brand
        current.imageData = edited.imageData
        items[index] = current
    }

    /// Deletes an item (tombstone via SyncEngine). Auch nie gesendete Artikel laufen über die Engine:
    /// Die ersetzte Anlage-Operation fällt dabei weg, und die Löschung erreicht alle Geräte.
    func deleteItem(_ item: ItemModel) {
        if !isBulkDeleting {
            let displayName = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            UserLog.Data.itemDeleted(
                name: displayName.isEmpty ? "Artikel" : displayName,
                units: item.units,
                measure: item.measure
            )
        }
        items.removeAll { $0.id == item.id }
        guard let syncEngine else { return }
        Task { await syncEngine.deleteItem(item) }
    }
    
    /// Re-queues a permanently-failed item for sync.
    func retryItem(_ item: ItemModel) {
        Task { await syncEngine?.retryItem(item) }
    }

    /// Toggles the checked state of an item and persists the change via updateItem.
    /// Uses optimistic update: UI changes immediately for instant feedback, then syncs to backend.
    func toggleItemChecked(_ item: ItemModel) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let wasComplete = isShoppingComplete
        defer { noteCheckChange(wasComplete: wasComplete) }

        // Optimistic update: toggle in-place, then re-sort according to currentSortOrder.
        // This prevents "double jump" and keeps the order consistent with any remote snapshots.
        var updatedItem = items[index]
        updatedItem.isChecked.toggle()
        items[index] = updatedItem
        items = ListViewModel.currentSortOrder.apply(to: items)

        // Specific check/uncheck log — suppresses generic "bearbeitet" in updateItem.
        let displayName = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        let resolvedName = displayName.isEmpty ? "Artikel" : displayName
        if updatedItem.isChecked {
            UserLog.Data.itemChecked(name: resolvedName, units: updatedItem.units, measure: updatedItem.measure)
        } else {
            UserLog.Data.itemUnchecked(name: resolvedName, units: updatedItem.units, measure: updatedItem.measure)
        }

        pendingAnimatedItemIDs.insert(updatedItem.id)
        // Abhaken ändert den Artikelstamm nicht (vorher: alter Preis/Foto überschrieb den Stamm, Audit H7).
        updateItem(updatedItem, trackPendingAnimation: true, suppressUserLog: true, updateCatalog: false)
    }
    
    /// Aktueller Stand eines Artikels: aus der Anzeige, sonst aus SwiftData.
    internal func currentItem(id: String) -> ItemModel? {
        if let shown = items.first(where: { $0.id == id }) { return shown }
        guard let uuid = UUID(uuidString: id), let entity = (try? itemStore.fetchItem(id: uuid)) ?? nil,
              entity.tombstone != true else { return nil }
        return entity.toItemModel()
    }

    /// Umbenennen = alten Artikel löschen + unter der ID des neuen Namens anlegen.
    /// Existiert der neue Name schon als eigener Artikel, bekommt der umbenannte eine eigene ID
    /// (kein stilles Überschreiben des vorhandenen Artikels).
    private func renameItem(from old: ItemModel, to edited: ItemModel, updateCatalog: Bool) {
        guard let listUUID = UUID(uuidString: edited.listId ?? "") else { return }
        let target = UUID.deterministicItemID(listId: listUUID, name: edited.name)
        let targetEntity = (try? itemStore.fetchItem(id: target)) ?? nil
        let targetIsLive = targetEntity != nil && targetEntity?.tombstone != true
        let renamed = edited.withId((targetIsLive ? UUID() : target).uuidString)
        logVoid(params: (action: "renameItem", from: old.id, to: renamed.id))
        UserLog.Data.itemUpdated(name: renamed.name)
        if updateCatalog { saveToCatalog(renamed, barcode: nil) }
        if let index = items.firstIndex(where: { $0.id == old.id }) { items[index] = renamed }
        guard let syncEngine else { return }
        Task {
            await syncEngine.deleteItem(old)
            await syncEngine.updateItem(renamed)      // legt unter der neuen ID an
            self.refreshItemsFromStore()
        }
    }

    // MARK: - Remote Sync Highlight

    /// Marks items as recently synced from a remote source and schedules their removal after 2 seconds.
    /// Safe to call with an overlapping set — `formUnion` is idempotent.
    /// The removal subtracts only the IDs passed in this call, so a concurrent markRecentlySynced()
    /// for different items is not affected.
    internal func markRecentlySynced(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        recentlySyncedItemIDs.formUnion(ids)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            self.recentlySyncedItemIDs.subtract(ids)
        }
    }

    // MARK: - Error Handling

    /// Stores a user-presentable error string on the main actor.
    @MainActor
    internal func setError(_ error: Error) {
        self.errorMessage = (error as NSError).localizedDescription
    }
}

// MARK: - Measure Canonicalization

private extension ListViewModel {
    /// Converts a free-form measure string to a normalized token using the Measure enum.
    func canonicalizeMeasure(_ raw: String) -> String {
        MeasureCanonicalizer.canonicalize(raw)
    }
}
