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
 - Remote-Zeilen gleicht SwiftDataItemStore.mergeRemote per HLC ab (ItemSyncPolicy).
 - Löschmarkierungen bleiben lokal erhalten (ausgeblendet über deletedAt).

 📝 Last Change:
 - Toter Merge-/Tombstone-Code entfernt; Zeitmarke je Liste (Audit 25.09.2026).
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
            self.setError(error)
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
    
    // MARK: - lastSyncTimestamp (FAM-41)

    /// Zeitmarke des letzten Delta-Abgleichs einer Liste (Date.distantPast = alles holen).
    internal func loadLastSyncTimestamp(for list: UUID? = nil) -> Date {
        guard let iso = UserDefaults.standard.string(forKey: lastSyncTimestampKey(list ?? listId)),
              let date = PaginationCursor.postgrestFormatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return Date.distantPast
        }
        return date
    }

    /// Speichert die Zeitmarke mit Millisekunden (vorher: ganze Sekunden → Zeilen wurden doppelt geholt).
    internal func saveLastSyncTimestamp(_ date: Date, for list: UUID? = nil) {
        UserDefaults.standard.set(PaginationCursor.postgrestFormatter.string(from: date),
                                  forKey: lastSyncTimestampKey(list ?? listId))
    }

    /// Clears the persisted last-sync timestamp for the current list.
    internal func clearLastSyncTimestamp() {
        UserDefaults.standard.removeObject(forKey: lastSyncTimestampKey(listId))
    }

    private func lastSyncTimestampKey(_ list: UUID) -> String {
        "fam24_last_sync_ts_\(list.uuidString)"
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
            // Position is stabilised by re-inserting at the index the item held in self.items.
            // Field values are NOT frozen: the incoming snapshot's version is always used so that
            // concurrent field updates (e.g. units increment after duplicate-add) are immediately visible.
            for pendingId in pendingAnimatedItemIDs {
                guard let currentIndex = items.firstIndex(where: { $0.id == pendingId }) else { continue }

                if let remoteIndex = resolvedItems.firstIndex(where: { $0.id == pendingId }) {
                    // Item present in new snapshot: keep its updated field values, stabilise position only.
                    let updatedItem = resolvedItems.remove(at: remoteIndex)
                    let insertionIndex = min(currentIndex, resolvedItems.count)
                    resolvedItems.insert(updatedItem, at: insertionIndex)
                } else {
                    // Item absent from snapshot (removed while animation was in flight):
                    // fall back to previous behaviour and re-insert the local copy at stable position.
                    let insertionIndex = min(currentIndex, resolvedItems.count)
                    resolvedItems.insert(items[currentIndex], at: insertionIndex)
                }
            }
        }
        
        guard items != resolvedItems else { return }
        self.items = resolvedItems
    }
}

