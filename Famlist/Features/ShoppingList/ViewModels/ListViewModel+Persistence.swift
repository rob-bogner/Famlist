/*
 ListViewModel+Persistence.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension managing SwiftData persistence and local-first sync strategies.

 🛠 Includes:
 - Local snapshot loading/merging with remote data
 - Pending change storage for offline support
 - Sync status updates
 - Default list caching
 - Item deletion (soft delete and purge)

 🔰 Notes for Beginners:
 - SwiftData provides offline-first capability by mirroring remote state locally.
 - Merge strategy ensures unsynced local changes aren't overwritten by remote snapshots.
 - Tombstones (soft deletes) allow syncing deletes to the server before purging locally.

 📝 Last Change:
 - Extracted from ListViewModel.swift to follow one-type-per-file rule and reduce file size.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and error handling.

// MARK: - Local Persistence

extension ListViewModel {
    /// Loads the default list for the given owner and switches observation to it.
    /// - Parameter ownerId: The profile/user UUID owning the list.
    func loadDefaultList(ownerId: UUID) {
        guard let listsRepository else { return }
        if isLoading { return }
        if defaultList == nil, let cached = loadCachedDefaultList(ownerId: ownerId) {
            defaultList = cached
            switchList(to: cached.id)
        }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                let list = try await listsRepository.fetchDefaultList(for: ownerId)
                defaultList = list
                switchList(to: list.id)
                persistDefaultList(list)
            } catch {
                setError(error)
            }
        }
    }
    
    /// Attempts to fetch the current profile and then load the default list.
    /// - Parameter profiles: Repository used to fetch the current user's profile.
    @MainActor
    func retryLoadDefaultList(using profiles: ProfilesRepository) async {
        do {
            let me = try await profiles.myProfile()
            self.loadDefaultList(ownerId: me.id)
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
        }
    }
    
    /// Loads cached items from SwiftData and applies them to the published `items` array.
    internal func loadLocalSnapshot() {
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            applyItems(ListViewModel.currentSortOrder.apply(to: localItems))
        } catch {
            logVoid(params: (
                note: "loadLocalSnapshot",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Persists a remote snapshot into SwiftData so offline mode mirrors the latest server state.
    /// FAM-79: Purge logic removed. Only upserts are performed.
    /// Items are deleted exclusively via applyRemoteTombstone() / applyRemoteTombstoneModel().
    internal func persistRemoteSnapshot(_ snapshot: [ItemModel]) {
        do {
            for model in snapshot {
                try itemStore.upsert(model: model)
            }
            try itemStore.save()
        } catch {
            logVoid(params: (
                note: "persistRemoteSnapshot",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Merges the latest remote snapshot with unsynced local mutations to provide a consistent view.
    /// Sortiert das Ergebnis stets nach currentSortOrder, damit Remote-Snapshots die UI-Reihenfolge nicht resetten.
    internal func mergeRemoteSnapshot(_ snapshot: [ItemModel]) -> [ItemModel] {
        let strategy = ItemMergeStrategy(
            currentItems: items,
            localStore: itemStore,
            listId: listId
        )
        let merged = strategy.merge(snapshot)
        return ListViewModel.currentSortOrder.apply(to: merged)
    }
    
    /// Stores a pending change locally and refreshes the published items, keeping offline UI in sync.
    internal func storePendingChange(for item: ItemModel, status: ItemEntity.SyncStatus) {
        do {
            let entity = try itemStore.upsert(model: item)
            entity.setSyncStatus(status)
            try itemStore.save()
            refreshItemsFromStore()
        } catch {
            logVoid(params: (
                note: "storePendingChange",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Marks an item as deleted in the local store while keeping a tombstone for later sync.
    internal func markItemDeleted(_ item: ItemModel) {
        guard let uuid = UUID(uuidString: item.id) else { return }
        do {
            try itemStore.delete(id: uuid)
            refreshItemsFromStore()
        } catch {
            logVoid(params: (
                note: "markItemDeleted",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Updates the sync status for an item when a remote operation finishes or fails.
    internal func updateSyncStatus(for itemId: String, status: ItemEntity.SyncStatus) {
        guard let uuid = UUID(uuidString: itemId) else { return }
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
            logVoid(params: (
                note: "updateSyncStatus",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Returns ALL items for the current list from SwiftData, including soft-deleted ones.
    /// Used by `ImportMergeService` to make correct merge decisions (create / reactivate / update).
    internal func fetchAllLocalItems() -> [ItemModel] {
        do {
            return try itemStore.fetchItems(listId: listId, includeDeleted: true).map { $0.toItemModel() }
        } catch {
            logVoid(params: (note: "fetchAllLocalItems.error", error: (error as NSError).localizedDescription))
            return []
        }
    }

    /// Re-reads the current list from SwiftData and publishes it.
    /// No-op while `isBulkDeleting` is true to avoid per-item re-renders during bulk operations.
    /// Also lazily clears `pendingBulkDeleteIDs` for items that are no longer active in SwiftData,
    /// so the guard dissolves naturally as async SyncEngine tasks confirm each deletion.
    internal func refreshItemsFromStore() {
        guard !isBulkDeleting else { return }
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            if !pendingBulkDeleteIDs.isEmpty {
                let activeIDs = Set(localItems.map { $0.id })
                pendingBulkDeleteIDs = pendingBulkDeleteIDs.intersection(activeIDs)
            }
            applyItems(ListViewModel.currentSortOrder.apply(to: localItems))
        } catch {
            logVoid(params: (
                note: "refreshItemsFromStore",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    // MARK: - Tombstone (FAM-41)

    /// Applies a remote tombstone for `item` directly in SwiftData (used by IncrementalSync delta).
    /// Uses HLC-aware conflict resolution: remote tombstone wins unless local HLC is strictly higher.
    internal func applyRemoteTombstoneModel(_ item: ItemModel) {
        guard let uuid = UUID(uuidString: item.id),
              let entity = try? itemStore.fetchItem(id: uuid) else { return }

        switch entity.syncStatus {
        case .synced, .pendingDelete, .failed, .pendingRecovery:
            try? itemStore.purge(id: uuid)
            logVoid(params: (action: "applyRemoteTombstoneModel.purge", itemId: item.id))

        case .pendingCreate, .pendingUpdate:
            let remoteHlcTimestamp = item.hlcTimestamp ?? 0
            let remoteHlcCounter = item.hlcCounter ?? 0
            let remoteHLC = HybridLogicalClock(
                timestamp: remoteHlcTimestamp,
                counter: remoteHlcCounter,
                nodeId: item.hlcNodeId ?? ""
            )
            let localHLC = HybridLogicalClock(
                timestamp: entity.hlcTimestamp ?? 0,
                counter: entity.hlcCounter ?? 0,
                nodeId: entity.hlcNodeId ?? ""
            )
            // Remote tombstone wins if remote >= local (tie → delete wins).
            if !(localHLC > remoteHLC) {
                try? itemStore.purge(id: uuid)
                logVoid(params: (action: "applyRemoteTombstoneModel.purge", itemId: item.id, reason: "remoteHlcWins"))
            } else {
                logVoid(params: (action: "applyRemoteTombstoneModel.localWins", itemId: item.id))
            }
        }
    }

    // MARK: - lastSyncTimestamp (FAM-41)

    /// Loads the high-water mark timestamp for the current list from UserDefaults.
    /// Returns Date.distantPast when no timestamp is stored (triggers a full delta-fetch on first run).
    internal func loadLastSyncTimestamp() -> Date {
        let key = lastSyncTimestampKey
        guard let iso = UserDefaults.standard.string(forKey: key),
              let date = ISO8601DateFormatter().date(from: iso) else {
            return Date.distantPast
        }
        return date
    }

    /// Persists the high-water mark timestamp for the current list to UserDefaults.
    internal func saveLastSyncTimestamp(_ date: Date) {
        let iso = ISO8601DateFormatter().string(from: date)
        UserDefaults.standard.set(iso, forKey: lastSyncTimestampKey)
    }

    /// Clears the persisted last-sync timestamp for the current list.
    internal func clearLastSyncTimestamp() {
        UserDefaults.standard.removeObject(forKey: lastSyncTimestampKey)
    }

    private var lastSyncTimestampKey: String {
        "fam24_last_sync_ts_\(listId.uuidString)"
    }

    // MARK: - Default List Caching

    private func loadCachedDefaultList(ownerId: UUID) -> ListModel? {
        do {
            let lists = try listStore.fetchLists(ownerId: ownerId)
            return lists.first(where: { $0.isDefault })?.toListModel()
        } catch {
            logVoid(params: (
                note: "loadCachedDefaultList",
                error: (error as NSError).localizedDescription
            ))
            return nil
        }
    }
    
    /// Persists the resolved default list into SwiftData for offline reuse.
    private func persistDefaultList(_ list: ListModel) {
        do {
            _ = try listStore.upsert(model: list)
            try listStore.save()
        } catch {
            logVoid(params: (
                note: "persistDefaultList",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Applies a new array of items to the published state, avoiding redundant UI updates.
    /// Filters out `pendingBulkDeleteIDs` to prevent Realtime snapshots or async callbacks
    /// from reinstating items that have been removed from the UI but are still in-flight.
    /// - Parameter newItems: Items we want to present.
    internal func applyItems(_ newItems: [ItemModel]) {
        let safeItems = pendingBulkDeleteIDs.isEmpty
            ? newItems
            : newItems.filter { !pendingBulkDeleteIDs.contains($0.id) }
        var resolvedItems = safeItems
        
        if !pendingAnimatedItemIDs.isEmpty {
            // Preserve the local ordering for items that currently have an optimistic animation in flight.
            for pendingId in pendingAnimatedItemIDs {
                guard let currentIndex = items.firstIndex(where: { $0.id == pendingId }) else { continue }
                let currentItem = items[currentIndex]
                
                if let remoteIndex = resolvedItems.firstIndex(where: { $0.id == pendingId }) {
                    resolvedItems.remove(at: remoteIndex)
                }
                
                let insertionIndex = min(currentIndex, resolvedItems.count)
                resolvedItems.insert(currentItem, at: insertionIndex)
            }
        }
        
        guard items != resolvedItems else { return }
        self.items = resolvedItems
    }
}

