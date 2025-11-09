// MARK: - ListViewModel.swift

/*
 ListViewModel.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - ObservableObject powering shopping list screens. Manages in‑memory state of items, and provides derived projections (progress, filtered arrays) and input helper methods used by views.

 🛠 Includes:
 - Start & manage items observation (live updates via repository)
 - CRUD (add / update / delete / toggle)
 - Unit measure canonicalization (free‑form user input -> normalized token)
 - Derived metrics (progressFraction, checked / unchecked arrays)
 - Form & quick‑add bridging helpers (string -> numeric / normalized fields)
 - Lightweight error & loading flags for UI feedback
 - Default list loading via ListsRepository (fetch or create user default)

 🔰 Notes for Beginners:
 - Repository abstraction (ItemsRepository, ListsRepository) enables mocking in tests.
 - @Published drives SwiftUI diffing automatically; mutations occur on main thread.
 - All public methods are @MainActor-only because SwiftUI expects UI changes on the main thread.

 📝 Last Change:
 - Optimized deleteItem() to skip Supabase DELETE for .pendingCreate items (only purge locally).
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID, DispatchSemaphore, and base types used here.
import SwiftUI // SwiftUI is needed for ObservableObject and @Published used by the view model.
import Combine // Combine provides AnyCancellable used for connectivity monitoring.

/// ViewModel encapsulating shopping list state and repository synchronization.
@MainActor // Guarantees that all state changes happen on the main thread (UI thread).
class ListViewModel: ObservableObject { // ObservableObject lets SwiftUI observe changes to @Published properties.
    // MARK: - Dependencies & Core State
    private let repository: ItemsRepository // Abstraction over the data source (Supabase or in-memory preview).
    private(set) var listId: UUID // Current list context; switching replaces the observed stream of items.

    @Published var items: [ItemModel] = [] // The items currently displayed in the UI. Changes re-render views.
    @Published var selectedItem: ItemModel? // The item currently selected for editing (opens EditItemView sheet).
    @Published var errorMessage: String? // Optional error message surfaced to the UI on operation failures.
    @Published var isLoading: Bool = false // Indicates when the view is performing a long-running action.
    @Published var defaultList: ListModel? = nil // The resolved default list for the current user; nil while loading.

    private var observeTask: Task<Void, Never>? = nil // Holds the background task that observes live item changes.

    // Optional ListsRepository used to resolve default list (injected post-init to keep compatibility)
    private var listsRepository: ListsRepository? = nil // Set via configure(listsRepository:).
    private var itemStore: SwiftDataItemStore? = nil // Local SwiftData store for offline persistence.
    private var listStore: SwiftDataListStore? = nil // Local SwiftData store for list metadata.
    private var connectivityCancellable: AnyCancellable? = nil // Retains connectivity subscription so it lives with the view model.
    private var hasObservedActiveList: Bool = false // Tracks whether realtime observation has started at least once.

    /// Enumerates triggers that can resume realtime sync to aid logging and debugging.
    private enum ResumeTrigger: String { case appForeground, connectivity } // Lists reasons we reattach to remote stream.

    // MARK: - Lifecycle
    /// Creates a ListViewModel with a target list and a repository (defaults to preview repo for development/previews).
    /// - Parameters:
    ///   - listId: Initial list identifier to scope observations to.
    ///   - repository: ItemsRepository implementation for data access.
    ///   - startImmediately: Whether to start observing items immediately (set false until auth ready).
    init(listId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), repository: ItemsRepository = PreviewItemsRepository(), startImmediately: Bool = true) {
        self.listId = listId // Store which list we are managing.
        self.repository = repository // Store the data source implementation.
        if startImmediately { startObserving() } // Begin listening for item updates only when requested.
    }
    deinit {
        observeTask?.cancel() // Cancel observation task to prevent dangling realtime streams.
        connectivityCancellable?.cancel() // Stop listening to connectivity changes when the view model deallocates.
    }

    // MARK: - Configuration
    /// Injects a ListsRepository used to fetch/create the user's default list.
    /// - Parameter listsRepository: Concrete implementation (Supabase or Preview) resolving default list rows.
    func configure(listsRepository: ListsRepository) { // Allow late binding from App entry after client init.
        self.listsRepository = listsRepository // Store for later use.
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
        connectivityCancellable = connectivityMonitor.$isOnline // Observe published online flag.
            .removeDuplicates() // Ignore duplicate states to avoid redundant resumes.
            .sink { [weak self] isOnline in // React to connectivity changes.
                guard let self else { return } // Ensure self still alive.
                if isOnline { self.resumeRealtimeSync(trigger: .connectivity) } // Resume sync when network becomes reachable.
            }
    }

    /// Loads the default list for the given owner and switches observation to it.
    /// - Parameter ownerId: The profile/user UUID owning the list.
    func loadDefaultList(ownerId: UUID) {
        guard let listsRepository else { return } // Nothing to do without a lists repository.
        if isLoading { return } // Prevent concurrent loads from overlapping.
        if defaultList == nil, let cached = loadCachedDefaultList(ownerId: ownerId) { // Try to reuse cached list for instant UI boot.
            defaultList = cached
            switchList(to: cached.id)
        }
        
        Task { @MainActor [weak self] in // Perform async fetch on a background task.
            guard let self else { return } // Capture self.
            isLoading = true // Show a lightweight loading indicator in the UI.
            defer { isLoading = false } // Always reset loading flag on completion.
            
            do { // Try to fetch or create default list.
                let list = try await listsRepository.fetchDefaultList(for: ownerId) // Resolve default list.
                defaultList = list // Publish resolved default list.
                switchList(to: list.id) // Switch observation to the new list id.
                persistDefaultList(list) // Mirror list locally for offline usage.
            } catch { // Surface errors to UI.
                setError(error) // Store error message.
            }
        }
    }

    // MARK: - List Switching
    /// Switches the active list; cancels current observation and starts a new one for the new list id.
    func switchList(to newId: UUID) {
        guard newId != self.listId else { return } // Bail out if the requested list is already active.
        observeTask?.cancel() // Stop observing the old list to prevent duplicate updates.
        self.listId = newId // Update state with the new list context.
        self.items = [] // Clear current items to avoid showing stale data briefly.
        startObserving() // Start observing items for the new list.
    }

    /// Clears view model state in response to sign-out.
    func clearForSignOut() { // Reset state so UI shows the loading/auth gate again.
        observeTask?.cancel() // Stop observing items.
        observeTask = nil // Release the task.
        items = [] // Drop loaded items.
        selectedItem = nil // Clear selection.
        defaultList = nil // Forget resolved default list.
        errorMessage = nil // Clear any error.
        // Reset listId to default so switchList will work again after re-login
        listId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        refreshItemsFromStore() // Clear cached SwiftData snapshot from the published array.
        hasObservedActiveList = false // Mark observation as not yet started for the next session.
    }

    /// Attempts to fetch the current profile and then load the default list.
    /// - Parameter profiles: Repository used to fetch the current user's profile.
    @MainActor
    func retryLoadDefaultList(using profiles: ProfilesRepository) async { // Helper to trigger default list load post sign-in.
        do { // Try to fetch profile and then default list.
            let me = try await profiles.myProfile() // Obtain current profile to access owner id.
            self.loadDefaultList(ownerId: me.id) // Kick off default list loading.
        } catch { // Surface any error to UI for visibility.
            self.errorMessage = (error as NSError).localizedDescription // Store error message for the view to present.
        }
    }

    // MARK: - Real-time Observation
    /// Starts (or restarts) the background observation of items for the current listId.
    private func startObserving() {
        observeTask?.cancel() // Ensure any previous observer is cancelled before starting a new one.
        loadLocalSnapshot() // Seed UI with locally cached items before remote stream responds.
        hasObservedActiveList = true // Remember that realtime observation has been initialized at least once.
        observeTask = Task { [weak self] in // Spawn a new child task that will live until cancelled.
            guard let self else { return } // Capture self weakly to avoid retain cycles.
            for await snapshot in repository.observeItems(listId: listId) { // Iterate updates as they arrive from repository.
                await MainActor.run {
                    let merged = self.mergeRemoteSnapshot(snapshot)
                    let previousCount = self.items.count
                    let newCount = merged.count

                    // Only animate when items are added or removed, not when updated (to prevent visible re-sorting)
                    if previousCount != newCount {
                        withAnimation { self.items = merged }
                    } else {
                        self.items = merged
                    }
                    self.persistRemoteSnapshot(snapshot) // Mirror remote snapshot into SwiftData for offline usage.
                }
            }
        }
    }

    /// Signals that the app moved into the foreground so realtime sync should resume if it was suspended.
    func handleAppDidBecomeActive() {
        resumeRealtimeSync(trigger: .appForeground) // Attempt to resume observation when app becomes active.
    }

    /// Signals that the app transitioned to background so realtime observation can pause to save resources.
    func handleAppDidEnterBackground() {
        guard observeTask != nil else { return } // Nothing to cancel when observation not running.
        logVoid(params: (action: "pauseRealtimeSync", listId: listId, reason: "background")) // Log suspension for diagnostics.
        observeTask?.cancel() // Cancel the running observation task so it does not hold resources while backgrounded.
        observeTask = nil // Release task reference so resume knows to recreate it.
    }

    // MARK: - CRUD (bridged to async/await)
    /// Adds a new item after normalizing fields (e.g., measure, listId).
    func addItem(_ item: ItemModel) {
        var normalized = item // Work on a mutable copy to keep parameter immutable.
        normalized.measure = canonicalizeMeasure(item.measure) // Normalize user-provided measure to a known token.
        normalized.listId = normalized.listId ?? listId.uuidString // Ensure the item carries the current list id.
        storePendingChange(for: normalized, status: .pendingCreate) // Persist locally so offline UI updates immediately.
        Task { [weak self] in // Run the repository call asynchronously.
            guard let self else { return }
            do {
                let created = try await self.repository.createItem(normalized) // Create item in the repository.
                await MainActor.run { self.updateSyncStatus(for: created.id, status: .synced) }
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
        var normalized = item // Copy for mutation.
        normalized.measure = canonicalizeMeasure(item.measure) // Normalize measure text.
        normalized.listId = normalized.listId ?? listId.uuidString // Ensure list context is present.
        storePendingChange(for: normalized, status: .pendingUpdate) // Persist change locally while remote call runs.
        Task { [weak self] in // Perform async update.
            guard let self else { return }
            do {
                try await self.repository.updateItem(normalized) // Persist changes.
                await MainActor.run { self.updateSyncStatus(for: normalized.id, status: .synced) }
            } catch {
                await MainActor.run {
                    self.updateSyncStatus(for: normalized.id, status: .failed)
                    self.setError(error)
                }
            }
        }
    }

    /// Deletes an item by id within the current list.
    /// Optimization: Items with status `.pendingCreate` are only purged locally without Supabase call.
    func deleteItem(_ item: ItemModel) {
        // Check if this item only exists locally (never synced to Supabase yet)
        guard let itemStore, let uuid = UUID(uuidString: item.id) else {
            markItemDeleted(item) // Fallback to normal flow if store unavailable.
            return
        }
        
        // Fetch the entity to check its sync status
        guard let entity = try? itemStore.fetchItem(id: uuid) else {
            markItemDeleted(item) // Fallback to normal flow if entity not found.
            return
        }
        
        // If item was never synced, just purge it locally without API call
        if entity.syncStatus == .pendingCreate {
            do {
                try itemStore.purge(id: uuid) // Remove from local store completely.
                refreshItemsFromStore() // Update UI immediately.
                return // Skip Supabase DELETE call - item never existed there.
            } catch {
                logVoid(params: (note: "deleteItem purge failed", error: (error as NSError).localizedDescription))
                setError(error) // Show error to user if purge fails.
                return
            }
        }
        
        // For synced/pendingUpdate/failed items: use normal deletion flow
        markItemDeleted(item) // Soft-delete locally first for immediate UI feedback.
        Task { [weak self] in // Async call wrapper.
            guard let self else { return }
            do {
                try await self.repository.deleteItem(id: item.id, listId: self.listId) // Delete by id for active list.
                await MainActor.run {
                    if let uuid = UUID(uuidString: item.id) {
                        try? self.itemStore?.purge(id: uuid) // Remove tombstone after remote confirmation.
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
        var copy = item // Copy the item so we can mutate it safely.
        copy.isChecked.toggle() // Flip the boolean from true -> false or vice versa.
        updateItem(copy) // Reuse update flow to persist.
    }

    // MARK: - Derived Projections
    /// Total number of items currently loaded.
    var totalItemCount: Int { items.count }
    /// Number of items whose isChecked flag is true.
    var checkedItemCount: Int { items.filter { $0.isChecked }.count }
    /// Returns a 0...1 fraction for progress UI (0 when list is empty to avoid NaN).
    var progressFraction: Double { totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount) }
    /// Convenience array of items that are not checked yet.
    /// Maintains stable sort order by preserving the order from items array.
    var uncheckedItems: [ItemModel] { items.filter { !$0.isChecked } }
    /// Convenience array of items that are checked already.
    /// Maintains stable sort order by preserving the order from items array.
    var checkedItems: [ItemModel] { items.filter { $0.isChecked } }

    // MARK: - View Input Helpers
    /// Creates and persists a new item from simple text inputs as used by the AddItemView form.
    func addItemFromInput(name: String, units: String, measure: String, image: UIImage? = nil) {
        isLoading = true // Show a lightweight loading indicator in the UI.
        let imageBase64 = image?.toBase64() // Convert optional image to Base64 string for persistence.
        let canonical = canonicalizeMeasure(measure) // Normalize measure before storing.
        let newItem = ItemModel(imageData: imageBase64, name: name, units: Int(units) ?? 1, measure: canonical, price: 0.0, isChecked: false, listId: listId.uuidString) // Build model.
        storePendingChange(for: newItem, status: .pendingCreate) // Mirror locally so UI updates even offline.
        Task { [weak self] in // Persist asynchronously to keep UI responsive.
            guard let self else { return }
            do {
                let created = try await self.repository.createItem(newItem) // Create in repository.
                await MainActor.run { self.updateSyncStatus(for: created.id, status: .synced) }
            } catch {
                await MainActor.run {
                    self.updateSyncStatus(for: newItem.id, status: .failed)
                    self.setError(error)
                }
            }
            await MainActor.run { self.isLoading = false } // Hide loading flag on main thread.
        }
    }

    /// Quick add from a single text field; trims and validates minimal input then delegates to addItemFromInput.
    func addQuickItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines) // Remove surrounding spaces/newlines.
        guard !trimmed.isEmpty else { return } // Ignore empty input.
        addItemFromInput(name: trimmed, units: "1", measure: "") // Default to 1 unit and no measure.
    }

    /// Updates an item using string fields from EditItemView, performing conversions and normalization.
    func updateItemFromInput(
        id: String,
        name: String,
        units: String,
        measure: String,
        price: String,
        isChecked: Bool,
        category: String?,
        productDescription: String?,
        brand: String?,
        image: UIImage?
    ) {
        isLoading = true // Indicate background work.
        let imageBase64 = image?.toBase64() // Convert image to Base64 if present.
        let canonical = canonicalizeMeasure(measure) // Normalize measure text.
        let updated = ItemModel(
            id: id,
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: canonical,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0, // Convert localized string to Double.
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId.uuidString
        ) // Construct the updated model to persist.
        storePendingChange(for: updated, status: .pendingUpdate) // Persist local mutation to keep UI responsive.
        Task { [weak self] in // Async persistence.
            guard let self else { return }
            do {
                try await self.repository.updateItem(updated) // Update in repository.
                await MainActor.run { self.updateSyncStatus(for: updated.id, status: .synced) }
            } catch {
                await MainActor.run {
                    self.updateSyncStatus(for: updated.id, status: .failed)
                    self.setError(error)
                }
            }
            await MainActor.run { self.isLoading = false } // Reset loading flag.
        }
    }

    // MARK: - Local Persistence
    /// Loads cached items from SwiftData and applies them to the published `items` array.
    private func loadLocalSnapshot() {
        guard let itemStore else { return }
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            withAnimation { self.items = localItems }
        } catch {
            logVoid(params: (note: "loadLocalSnapshot", error: (error as NSError).localizedDescription))
        }
    }

    /// Persists a remote snapshot into SwiftData so offline mode mirrors the latest server state.
    private func persistRemoteSnapshot(_ snapshot: [ItemModel]) {
        guard let itemStore else { return }
        do {
            let remoteIds = Set(snapshot.map { $0.id })
            for model in snapshot {
                let entity = try itemStore.upsert(model: model)
                entity.setSyncStatus(.synced)
            }
            let existing = try itemStore.fetchItems(listId: listId, includeDeleted: true)
            for entity in existing where entity.syncStatus == .synced && !remoteIds.contains(entity.id.uuidString) {
                try itemStore.purge(id: entity.id)
            }
            try itemStore.save()
        } catch {
            logVoid(params: (note: "persistRemoteSnapshot", error: (error as NSError).localizedDescription))
        }
    }

    /// Merges the latest remote snapshot with unsynced local mutations to provide a consistent view.
    /// Preserves the current items array order to prevent re-sorting.
    private func mergeRemoteSnapshot(_ snapshot: [ItemModel]) -> [ItemModel] {
        guard let itemStore else { return snapshot }
        do {
            let localEntities = try itemStore.fetchItems(listId: listId, includeDeleted: true)
            var merged = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })

            // Apply local pending changes
            for entity in localEntities {
                let id = entity.id.uuidString
                switch entity.syncStatus {
                case .pendingDelete:
                    merged.removeValue(forKey: id)
                case .pendingCreate, .pendingUpdate, .pendingRecovery, .failed:
                    merged[id] = entity.toItemModel()
                case .synced:
                    break
                }
            }

            // Preserve current order by starting with existing items array
            var ordered: [ItemModel] = []
            let currentIds = Set(items.map { $0.id })

            // First, keep all existing items in their current order (updated with new data)
            for existingItem in items {
                if let updatedItem = merged.removeValue(forKey: existingItem.id) {
                    ordered.append(updatedItem)
                }
            }

            // Then append any new items from snapshot that weren't in current items
            for item in snapshot {
                if !currentIds.contains(item.id), let newItem = merged.removeValue(forKey: item.id) {
                    ordered.append(newItem)
                }
            }

            // Finally, append any pending local creates
            for entity in localEntities {
                let key = entity.id.uuidString
                if let value = merged.removeValue(forKey: key) {
                    ordered.append(value)
                }
            }

            if !merged.isEmpty { ordered.append(contentsOf: merged.values) }
            return ordered
        } catch {
            logVoid(params: (note: "mergeRemoteSnapshot", error: (error as NSError).localizedDescription))
            return snapshot
        }
    }

    /// Stores a pending change locally and refreshes the published items, keeping offline UI in sync.
    private func storePendingChange(for item: ItemModel, status: ItemEntity.SyncStatus) {
        guard let itemStore else { return }
        do {
            let entity = try itemStore.upsert(model: item)
            entity.setSyncStatus(status)
            try itemStore.save()
            refreshItemsFromStore()
        } catch {
            logVoid(params: (note: "storePendingChange", error: (error as NSError).localizedDescription))
        }
    }

    /// Marks an item as deleted in the local store while keeping a tombstone for later sync.
    private func markItemDeleted(_ item: ItemModel) {
        guard let itemStore, let uuid = UUID(uuidString: item.id) else { return }
        do {
            try itemStore.delete(id: uuid)
            refreshItemsFromStore()
        } catch {
            logVoid(params: (note: "markItemDeleted", error: (error as NSError).localizedDescription))
        }
    }

    /// Updates the sync status for an item when a remote operation finishes or fails.
    private func updateSyncStatus(for itemId: String, status: ItemEntity.SyncStatus) {
        guard let itemStore, let uuid = UUID(uuidString: itemId) else { return }
        do {
            if let entity = try itemStore.fetchItem(id: uuid) {
                entity.setSyncStatus(status)
                if status == .failed {
                    entity.deletedAt = nil // Restore visibility when a delete failed.
                }
                try itemStore.save()
                refreshItemsFromStore()
            }
        } catch {
            logVoid(params: (note: "updateSyncStatus", error: (error as NSError).localizedDescription))
        }
    }

    /// Re-reads the current list from SwiftData and publishes it.
    private func refreshItemsFromStore() {
        guard let itemStore else { return }
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            withAnimation { self.items = localItems }
        } catch {
            logVoid(params: (note: "refreshItemsFromStore", error: (error as NSError).localizedDescription))
        }
    }

    /// Reads the cached default list for the given owner when available.
    private func loadCachedDefaultList(ownerId: UUID) -> ListModel? {
        guard let listStore else { return nil }
        do {
            let lists = try listStore.fetchLists(ownerId: ownerId)
            return lists.first(where: { $0.isDefault })?.toListModel()
        } catch {
            logVoid(params: (note: "loadCachedDefaultList", error: (error as NSError).localizedDescription))
            return nil
        }
    }

    /// Persists the resolved default list into SwiftData for offline reuse.
    private func persistDefaultList(_ list: ListModel) {
        guard let listStore else { return }
        do {
            _ = try listStore.upsert(model: list)
            try listStore.save()
        } catch {
            logVoid(params: (note: "persistDefaultList", error: (error as NSError).localizedDescription))
        }
    }

}

// MARK: - Measure Canonicalization
private extension ListViewModel {
    /// Converts a free-form measure string to a normalized token using the Measure enum.
    func canonicalizeMeasure(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines) // Trim spaces.
        guard !trimmed.isEmpty else { return "" } // Keep empty when user provided nothing.
        return Measure.fromExternal(trimmed).rawValue // Map to enum case and return its canonical raw value.
    }
    /// Stores a user-presentable error string on the main actor.
    @MainActor
    func setError(_ error: Error) {
        self.errorMessage = (error as NSError).localizedDescription // Convert to readable message for UI.
    }

    /// Restarts realtime observation if a prior observation existed and logs the trigger for debugging.
    private func resumeRealtimeSync(trigger: ResumeTrigger) {
        guard hasObservedActiveList else { return } // Skip until at least one observation has been established.
        logVoid(params: (action: "resumeRealtimeSync", listId: listId, trigger: trigger.rawValue)) // Log resume attempt with trigger context.
        startObserving() // Recreate observation and fetch the latest snapshot.
    }
}

