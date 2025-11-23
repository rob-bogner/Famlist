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
            applyItems(localItems)
        } catch {
            logVoid(params: (
                note: "loadLocalSnapshot",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Persists a remote snapshot into SwiftData so offline mode mirrors the latest server state.
    internal func persistRemoteSnapshot(_ snapshot: [ItemModel]) {
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
            logVoid(params: (
                note: "persistRemoteSnapshot",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Merges the latest remote snapshot with unsynced local mutations to provide a consistent view.
    /// Preserves the current items array order to prevent re-sorting.
    internal func mergeRemoteSnapshot(_ snapshot: [ItemModel]) -> [ItemModel] {
        let strategy = ItemMergeStrategy(
            currentItems: items,
            localStore: itemStore,
            listId: listId
        )
        return strategy.merge(snapshot)
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
    
    /// Re-reads the current list from SwiftData and publishes it.
    internal func refreshItemsFromStore() {
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            applyItems(localItems)
        } catch {
            logVoid(params: (
                note: "refreshItemsFromStore",
                error: (error as NSError).localizedDescription
            ))
        }
    }
    
    /// Reads the cached default list for the given owner when available.
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
    /// - Parameter newItems: Items we want to present.
    internal func applyItems(_ newItems: [ItemModel]) {
        var resolvedItems = newItems
        
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

