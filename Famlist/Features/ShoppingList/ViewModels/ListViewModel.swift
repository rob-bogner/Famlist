// MARK: - ListViewModel.swift

/*
 ListViewModel.swift

 GroceryGenius
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
class ListViewModel: ObservableObject { // ObservableObject lets SwiftUI observe changes to @Published properties.
    
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
    
    /// Current list context; switching replaces the observed stream of items.
    private(set) var listId: UUID
    
    /// Optional ListsRepository used to resolve default list (injected post-init to keep compatibility).
    internal var listsRepository: ListsRepository?
    
    /// Local SwiftData store for offline persistence.
    internal var itemStore: SwiftDataItemStore?
    
    /// Local SwiftData store for list metadata.
    internal var listStore: SwiftDataListStore?
    
    /// Holds the background task that observes live item changes.
    internal var observeTask: Task<Void, Never>?
    
    /// Retains connectivity subscription so it lives with the view model.
    private var connectivityCancellable: AnyCancellable?
    
    /// Tracks whether realtime observation has started at least once.
    internal var hasObservedActiveList: Bool = false
    
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
    ///   - startImmediately: Whether to start observing items immediately (set false until auth ready).
    init(
        listId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
        repository: ItemsRepository = PreviewItemsRepository(),
        startImmediately: Bool = true
    ) {
        self.listId = listId // Store which list we are managing.
        self.repository = repository // Store the data source implementation.
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
    
    /// Injects SwiftData stores enabling local-first persistence for lists and items.
    /// - Parameters:
    ///   - itemStore: Store managing ItemEntity records within SwiftData.
    ///   - listStore: Store managing ListEntity records within SwiftData.
    func configure(localItemStore itemStore: SwiftDataItemStore, listStore: SwiftDataListStore) {
        self.itemStore = itemStore
        self.listStore = listStore
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
                }
            }
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
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new item after normalizing fields (e.g., measure, listId).
    func addItem(_ item: ItemModel) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString
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
    
    /// Updates an existing item after normalizing fields.
    func updateItem(_ item: ItemModel) {
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
        
        storePendingChange(for: normalized, status: .pendingUpdate)
        
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.updateItem(normalized)
                await MainActor.run {
                    self.updateSyncStatus(for: normalized.id, status: .synced)
                    logVoid(params: (action: "updateItem.success", itemId: normalized.id))
                }
            } catch {
                await MainActor.run {
                    self.updateSyncStatus(for: normalized.id, status: .failed)
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
    
    /// Deletes an item by id within the current list.
    /// Optimization: Items with status `.pendingCreate` are only purged locally without Supabase call.
    func deleteItem(_ item: ItemModel) {
        guard let itemStore, let uuid = UUID(uuidString: item.id) else {
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
        
        // For synced/pendingUpdate/failed items: use normal deletion flow
        markItemDeleted(item)
        
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.deleteItem(id: item.id, listId: self.listId)
                await MainActor.run {
                    if let uuid = UUID(uuidString: item.id) {
                        try? self.itemStore?.purge(id: uuid)
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
    
    /// Toggles the checked state of an item and persists the change via updateItem.
    /// Uses optimistic update: UI changes immediately for instant feedback, then syncs to backend.
    func toggleItemChecked(_ item: ItemModel) {
        // Optimistic update: Update UI immediately for instant feedback
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isChecked.toggle()
        }
        
        // Then sync to backend
        var copy = item
        copy.isChecked.toggle()
        updateItem(copy)
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
