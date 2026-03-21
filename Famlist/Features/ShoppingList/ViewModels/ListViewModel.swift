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

    /// The item currently selected for editing (opens EditItemView sheet).
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
    private(set) var listId: UUID
    
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
        observeTask?.cancel()
        self.listId = newId
        self.items = []
        recentlySyncedItemIDs = []
        // Reset pagination state for the new list (cursor is loaded from UserDefaults per listId in startObserving).
        currentCursor = PaginationCursor.load(listId: newId)
        hasMoreItems = true
        isLoadingNextPage = false
        consecutiveEmptyPages = 0
        startObserving()
    }
    
    /// Clears view model state in response to sign-out.
    func clearForSignOut() {
        observeTask?.cancel()
        observeTask = nil
        membershipTask?.cancel()
        membershipTask = nil
        items = []
        recentlySyncedItemIDs = []
        selectedItem = nil
        defaultList = nil
        allLists = []
        listItemCounts = [:]
        errorMessage = nil
        // Reset pagination state and clear persisted cursor/timestamp.
        PaginationCursor.clear(listId: listId)
        clearLastSyncTimestamp()
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
    func addItem(_ item: ItemModel) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString

        // Duplikat-Check: existiert bereits ein ungehacktes Item mit gleichem Namen?
        if let existingIndex = items.firstIndex(where: {
            $0.name.lowercased() == normalized.name.lowercased() && !$0.isChecked
        }) {
            var incremented = items[existingIndex]
            let oldUnits = incremented.units
            incremented.units = oldUnits + 1
            UserLog.Data.itemCountIncremented(
                name: incremented.name,
                from: oldUnits,
                to: incremented.units,
                measure: incremented.measure
            )
            // Optimistic update: immediately reflect the incremented count in the UI
            // without waiting for the async SwiftData round-trip. The subsequent
            // refreshItemsFromStore() (inside updateItem's Task) will confirm the value.
            items[existingIndex] = incremented
            updateItem(incremented, suppressUserLog: true)
            return
        }

        // User-friendly log
        let displayName = [normalized.brand, normalized.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        UserLog.Data.itemAdded(
            name: displayName.isEmpty ? "Artikel" : displayName,
            units: normalized.units,
            measure: normalized.measure
        )

        // Save to personal item catalog (fire-and-forget; does not block list update).
        // ownerPublicId is resolved by the repository from the active auth session,
        // so we pass an empty placeholder here to avoid a nil-guard race condition.
        if let catalogRepo = catalogRepository {
            let catalogEntry = ItemCatalogEntry.from(item: normalized, ownerPublicId: "")
            Task {
                do {
                    try await catalogRepo.save(catalogEntry)
                    logVoid(params: (action: "catalogSave.success", itemName: normalized.name))
                } catch {
                    logVoid(params: (action: "catalogSave.failed", itemName: normalized.name, error: (error as NSError).localizedDescription))
                }
            }
        }

        // Optimistic UI add: show the item immediately without waiting for the
        // Realtime echo or the async refreshItemsFromStore() round-trip.
        // The subsequent refreshItemsFromStore() (inside the Task below) will replace
        // this entry with the authoritative SwiftData entity (deterministic UUID).
        items.append(normalized)

        guard let syncEngine else { return }
        Task {
            await syncEngine.createItem(normalized)
            // Refresh replaces the optimistic item with the canonical SwiftData entity.
            await MainActor.run { self.refreshItemsFromStore() }
        }
    }
    
    /// Updates an existing item after normalizing fields.
    /// - Parameter suppressUserLog: Pass `true` when the caller has already logged the action
    ///   (e.g. `toggleItemChecked`, increment path in `addItem`) to avoid duplicate logs.
    func updateItem(_ item: ItemModel, trackPendingAnimation: Bool = false, suppressUserLog: Bool = false) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString

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
        if let catalogRepo = catalogRepository {
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
    
    /// Deletes an item by id within the current list.
    /// Optimization: Items with status `.pendingCreate` are only purged locally without Supabase call.
    func deleteItem(_ item: ItemModel) {
        // User-friendly log — nur außerhalb Bulk-Delete, um N Einzellogs beim Bulk zu vermeiden
        if !isBulkDeleting {
            let displayName = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            UserLog.Data.itemDeleted(
                name: displayName.isEmpty ? "Artikel" : displayName,
                units: item.units,
                measure: item.measure
            )
        }
        
        guard let uuid = UUID(uuidString: item.id) else {
            markItemDeleted(item)
            return
        }
        
        guard let entity = try? itemStore.fetchItem(id: uuid) else {
            markItemDeleted(item)
            return
        }
        
        // If item was never synced, just purge it locally without API call
        if entity.syncStatus == .pendingCreate {
            do {
                try itemStore.purge(id: uuid)
                refreshItemsFromStore()
                return
            } catch {
                logVoid(params: (
                    note: "deleteItem purge failed",
                    error: (error as NSError).localizedDescription
                ))
                setError(error)
                return
            }
        }
        
        guard let syncEngine else { return }
        Task {
            await syncEngine.deleteItem(item)
        }
    }
    
    /// Re-queues a permanently-failed item for sync.
    func retryItem(_ item: ItemModel) {
        Task { await syncEngine?.retryItem(item) }
    }

    /// Toggles the checked state of an item and persists the change via updateItem.
    /// Uses optimistic update: UI changes immediately for instant feedback, then syncs to backend.
    func toggleItemChecked(_ item: ItemModel) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

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
        updateItem(updatedItem, trackPendingAnimation: true, suppressUserLog: true)
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
