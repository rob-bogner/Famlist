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
 - List switching and sign-out reset
 - Configuration → ListViewModel+Configuration.swift, CRUD → ListViewModel+ItemCRUD.swift,
   Sync-Hervorhebung/Fehler → ListViewModel+Feedback.swift

 🔰 Notes for Beginners:
 - This is the main class definition. Additional functionality is in extension files.
 - Repository abstraction enables mocking in tests.
 - @Published drives SwiftUI diffing automatically.
 - All public methods are @MainActor-only for thread safety.

 📝 Last Change:
 - Konfiguration, CRUD und Rückmeldungen in eigene Extensions ausgelagert (Audit 25.09.2026).
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
    internal var connectivityCancellable: AnyCancellable?

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
        // connectivityCancellable braucht hier kein cancel(): AnyCancellable beendet das Abo beim eigenen deinit
        // automatisch (Apple-Doku). Der nicht-Sendable-Typ darf im nicht isolierten deinit nicht angefasst werden.
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
        // Alle Artikel (inkl. Fotos) und Listen des Kontos vom Gerät löschen (Audit H5).
        do {
            try itemStore.deleteAll()
            try listStore.deleteAll()
        } catch {
            logVoid(params: (action: "clearForSignOut.deleteAll.error", error: (error as NSError).localizedDescription))
        }
        currentCursor = nil
        hasMoreItems = true
        isLoadingNextPage = false
        consecutiveEmptyPages = 0
        listId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        refreshItemsFromStore()
        hasObservedActiveList = false
        ListViewModel.currentSortOrder = .category
    }
}
