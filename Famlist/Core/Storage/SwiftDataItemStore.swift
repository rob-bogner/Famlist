/*
 SwiftDataItemStore.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Convenience wrapper handling ItemEntity persistence via SwiftData ModelContext.
 🛠 Includes: Fetch, upsert, delete, and list-scoped queries for items.
 🔰 Notes for Beginners: Keep SwiftData specifics here so view models and repositories stay clean.
 📝 Last Change: Preserve soft-deleted items and add a purge helper to clean up after remote confirmations.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID and Date.
import SwiftData // Supplies ModelContext, FetchDescriptor, and predicate helpers.

/// Lightweight store that encapsulates SwiftData operations for ItemEntity.
@MainActor
final class SwiftDataItemStore {
    /// Underlying SwiftData context used to perform CRUD.
    private let context: ModelContext

    /// Creates the store with the given ModelContext.
    /// - Parameter context: SwiftData context injected from the view hierarchy or composition root.
    init(context: ModelContext) {
        self.context = context
    }

    /// Fetches items belonging to a specific list identifier.
    /// - Parameter listId: The parent list UUID.
    /// - Returns: Array of ItemEntity ordered by creation date.
    func fetchItems(listId: UUID, includeDeleted: Bool = false) throws -> [ItemEntity] {
        let predicate: Predicate<ItemEntity>
        if includeDeleted {
            predicate = #Predicate { entity in
                entity.listId == listId
            }
        } else {
            predicate = #Predicate { entity in
                entity.listId == listId && entity.deletedAt == nil
            }
        }
        let descriptor = FetchDescriptor<ItemEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\ItemEntity.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches a single item by its identifier.
    /// - Parameter id: Item UUID to load.
    /// - Returns: Matching ItemEntity if present.
    func fetchItem(id: UUID) throws -> ItemEntity? {
        let descriptor = FetchDescriptor<ItemEntity>(
            predicate: #Predicate { $0.id == id },
            sortBy: []
        )
        return try context.fetch(descriptor).first
    }

    /// Inserts or updates an item using the provided ItemModel snapshot.
    /// - Parameters:
    ///   - model: ItemModel to mirror locally.
    ///   - listReference: Optional parent list entity to wire relationship immediately.
    /// - Returns: Persisted ItemEntity instance (new or updated).
    @discardableResult
    func upsert(model: ItemModel, listReference: ListEntity? = nil) throws -> ItemEntity {
        let resolvedId = UUID(uuidString: model.id) ?? UUID()
        if let existing = try fetchItem(id: resolvedId) {
            existing.apply(model: model)
            if let listReference {
                existing.list = listReference
            }
            return existing
        }
        let entity = ItemEntity.make(from: model, listReference: listReference)
        context.insert(entity)
        return entity
    }

    /// Updates only the checked status of an item for efficient batch operations.
    /// - Parameters:
    ///   - id: Item UUID to update.
    ///   - isChecked: New checked state.
    func updateCheckedStatus(id: UUID, isChecked: Bool) throws {
        guard let entity = try fetchItem(id: id) else { return }
        entity.isChecked = isChecked
        entity.updatedAt = Date()
        entity.setSyncStatus(.pendingUpdate)
        try save()
    }
    
    /// Batch updates checked status for multiple items without intermediate saves (optimized for bulk operations).
    /// - Parameters:
    ///   - ids: Array of item UUIDs to update.
    ///   - isChecked: New checked state for all items.
    func batchUpdateCheckedStatus(ids: [UUID], isChecked: Bool) throws {
        let updateDate = Date()
        for id in ids {
            guard let entity = try fetchItem(id: id) else { continue }
            entity.isChecked = isChecked
            entity.updatedAt = updateDate
            entity.setSyncStatus(.pendingUpdate)
        }
        // Single save at the end for better performance
        try save()
    }
    
    /// Soft deletes an item by marking sync status and removing it from the context.
    /// - Parameter id: Item UUID to remove.
    func delete(id: UUID) throws {
        guard let entity = try fetchItem(id: id) else { return }
        entity.setSyncStatus(.pendingDelete)
        try save()
    }

    /// Batch soft-deletes multiple items without intermediate saves.
    /// Items with `.pendingCreate` are purged immediately (never synced to server).
    /// - Parameter ids: Item UUIDs to delete.
    /// - Returns: UUIDs that were soft-deleted (not purged), for remote tombstone upsert.
    func batchDelete(ids: [UUID]) throws -> [UUID] {
        var softDeletedIds: [UUID] = []
        for id in ids {
            guard let entity = try fetchItem(id: id) else { continue }
            if entity.syncStatus == .pendingCreate {
                context.delete(entity)
            } else {
                entity.setSyncStatus(.pendingDelete)
                softDeletedIds.append(id)
            }
        }
        try save()
        return softDeletedIds
    }

    /// Marks multiple items as `.synced` in a single batch operation.
    /// Used after a successful bulk HTTP request to clear the `.pendingUpdate` status
    /// so that Realtime echo events are no longer suppressed by `hasPendingLocalChange`.
    func batchMarkSynced(ids: [UUID]) throws {
        for id in ids {
            guard let entity = try fetchItem(id: id) else { continue }
            entity.setSyncStatus(.synced)
        }
        try save()
    }

    /// Removes an item from the context once the remote delete has been confirmed.
    func purge(id: UUID) throws {
        guard let entity = try fetchItem(id: id) else { return }
        context.delete(entity)
        try save()
    }

    /// Persists outstanding changes on the context.
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Remote Tombstone

    /// Applies a remote tombstone: purges the item unless it has a pending local mutation
    /// with a strictly higher HLC.
    ///
    /// Conflict resolution rules:
    /// - `.synced`, `.pendingDelete`, `.failed`, `.pendingRecovery` → always purge.
    /// - `.pendingCreate`, `.pendingUpdate` → HLC comparison:
    ///     remote HLC >= local HLC → purge; local HLC > remote → keep local pending op.
    ///
    /// This is the single canonical implementation used by both `RealtimeEventProcessor`
    /// (for Realtime UPDATE events with tombstone=true) and `ListViewModel.runIncrementalSync()`
    /// (for IncrementalSync delta items with tombstone=true).
    ///
    /// - Parameters:
    ///   - itemId: UUID of the item to tombstone.
    ///   - remoteHLC: HLC from the remote tombstone event.
    /// - Returns: `true` if the item was purged, `false` if local wins.
    @discardableResult
    func applyRemoteTombstone(itemId: UUID, remoteHLC: HybridLogicalClock) -> Bool {
        guard let entity = try? fetchItem(id: itemId) else { return false }

        switch entity.syncStatus {
        case .synced, .pendingDelete, .failed, .pendingRecovery:
            try? purge(id: itemId)
            return true

        case .pendingCreate, .pendingUpdate:
            let localHLC = HybridLogicalClock(
                timestamp: entity.hlcTimestamp ?? 0,
                counter: entity.hlcCounter ?? 0,
                nodeId: entity.hlcNodeId ?? ""
            )
            // Remote tombstone wins if remote >= local (tie → delete wins).
            if !(localHLC > remoteHLC) {
                try? purge(id: itemId)
                return true
            }
            return false
        }
    }
}
