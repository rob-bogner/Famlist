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
    
    // MARK: - Dependencies & Core State
    
    /// Abstraction over the data source (Supabase or in-memory preview).
    internal let repository: ItemsRepository
    
    /// Central sync engine for CRDT-based operations (optional, nil in preview mode).
    internal var syncEngine: SyncEngine?
    
    /// Current list context; switching replaces the observed stream of items.
    private(set) var listId: UUID
    
    /// Optional ListsRepository used to resolve default list (injected post-init to keep compatibility).
    internal var listsRepository: ListsRepository?

    /// Optional personal item catalog repository; injected after init via configure(catalogRepository:).
    /// When set, new items are automatically saved to the catalog in the background.
    internal var catalogRepository: (any ItemCatalogRepository)?
    
    /// Local SwiftData store for offline persistence.
    internal let itemStore: SwiftDataItemStore
    
    /// Local SwiftData store for list metadata.
    internal let listStore: SwiftDataListStore
    
    /// Holds the background task that observes live item changes.
    internal var observeTask: Task<Void, Never>?
    
    /// Retains connectivity subscription so it lives with the view model.
    private var connectivityCancellable: AnyCancellable?
    
    /// Tracks whether realtime observation has started at least once.
    internal var hasObservedActiveList: Bool = false
    
    /// Item identifiers that currently have an optimistic reorder animation in flight.
    /// While they remain here, we keep the local ordering authoritative to avoid jitter.
    internal var pendingAnimatedItemIDs: Set<String> = []
    
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
    
    /// Injects the sync engine for CRDT-based operations
    /// - Parameter syncEngine: Configured sync engine instance
    func configure(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
    }

    /// Injects the personal item catalog repository for smart search support.
    /// - Parameter catalogRepository: Repository that saves/searches the user's item catalog.
    func configure(catalogRepository: any ItemCatalogRepository) {
        self.catalogRepository = catalogRepository
    }
    
    // MARK: - List Switching
    
    /// Switches the active list; cancels current observation and starts a new one for the new list id.
    func switchList(to newId: UUID) {
        guard newId != self.listId else { return }
        observeTask?.cancel()
        self.listId = newId
        self.items = []
        startObserving()
    }
    
    /// Clears view model state in response to sign-out.
    func clearForSignOut() {
        observeTask?.cancel()
        observeTask = nil
        items = []
        selectedItem = nil
        defaultList = nil
        errorMessage = nil
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

        // Use SyncEngine if available, otherwise fall back to old approach
        if let syncEngine = syncEngine {
            Task {
                await syncEngine.createItem(normalized)
            }
        } else {
            // Legacy path for preview mode without SyncEngine
            storePendingChange(for: normalized, status: .pendingCreate)
            
            Task { [weak self] in
                guard let self else { return }
                do {
                    let created = try await self.repository.createItem(normalized)
                    await MainActor.run {
                        self.updateSyncStatus(for: created.id, status: .synced)
                    }
                } catch {
                    await MainActor.run {
                        self.updateSyncStatus(for: normalized.id, status: .failed)
                        self.setError(error)
                    }
                }
            }
        }
    }
    
    /// Updates an existing item after normalizing fields.
    func updateItem(_ item: ItemModel, trackPendingAnimation: Bool = false) {
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
        // Note: User-Log erfolgt im Repository nach erfolgreichem Server-Update

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
        
        // Use SyncEngine if available, otherwise fall back to old approach
        if let syncEngine = syncEngine {
            Task {
                await syncEngine.updateItem(normalized)
                await MainActor.run {
                    if trackPendingAnimation {
                        self.pendingAnimatedItemIDs.remove(normalized.id)
                    }
                }
            }
        } else {
            // Legacy path for preview mode without SyncEngine
            storePendingChange(for: normalized, status: .pendingUpdate)
            
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.repository.updateItem(normalized)
                    await MainActor.run {
                        self.updateSyncStatus(for: normalized.id, status: .synced)
                        if trackPendingAnimation {
                            self.pendingAnimatedItemIDs.remove(normalized.id)
                        }
                        logVoid(params: (action: "updateItem.success", itemId: normalized.id))
                    }
                } catch {
                    await MainActor.run {
                        self.updateSyncStatus(for: normalized.id, status: .failed)
                        if trackPendingAnimation {
                            self.pendingAnimatedItemIDs.remove(normalized.id)
                        }
                        self.setError(error)
                        logVoid(params: (
                            action: "updateItem.error",
                            itemId: normalized.id,
                            error: (error as NSError).localizedDescription
                        ))
                    }
                }
            }
        }
    }
    
    /// Deletes an item by id within the current list.
    /// Optimization: Items with status `.pendingCreate` are only purged locally without Supabase call.
    func deleteItem(_ item: ItemModel) {
        // User-friendly log
        let displayName = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        UserLog.Data.itemDeleted(name: displayName.isEmpty ? "Artikel" : displayName)
        
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
        
        // Use SyncEngine if available, otherwise fall back to old approach
        if let syncEngine = syncEngine {
            Task {
                await syncEngine.deleteItem(item)
            }
        } else {
            // Legacy path for preview mode without SyncEngine
            markItemDeleted(item)
            
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.repository.deleteItem(id: item.id, listId: self.listId)
                    await MainActor.run {
                        if let uuid = UUID(uuidString: item.id) {
                            try? self.itemStore.purge(id: uuid)
                            self.refreshItemsFromStore()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.updateSyncStatus(for: item.id, status: .failed)
                        self.setError(error)
                    }
                }
            }
        }
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

        pendingAnimatedItemIDs.insert(updatedItem.id)
        updateItem(updatedItem, trackPendingAnimation: true)
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
