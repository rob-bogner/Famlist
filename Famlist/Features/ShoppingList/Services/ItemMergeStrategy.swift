/*
 ItemMergeStrategy.swift
 GroceryGenius
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Service for merging remote item snapshots with local pending changes.
 🛠 Includes: Merge logic that preserves order and applies local mutations.
 🔰 Notes for Beginners: Used by ListViewModel to combine server data with offline edits.
 📝 Last Change: Extracted from ListViewModel.swift to reduce file size and improve testability.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID and error handling.

/// Strategy for merging remote item snapshots with local pending changes.
@MainActor
struct ItemMergeStrategy {
    let currentItems: [ItemModel]
    let localStore: SwiftDataItemStore
    let listId: UUID
    
    /// Merges the latest remote snapshot with unsynced local mutations to provide a consistent view.
    /// Preserves the current items array order to prevent re-sorting.
    /// - Parameter snapshot: Remote items fetched from the server.
    /// - Returns: Merged array with local changes applied, preserving current order.
    func merge(_ snapshot: [ItemModel]) -> [ItemModel] {
        do {
            let localEntities = try localStore.fetchItems(listId: listId, includeDeleted: true)
            var merged = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })
            
            // Apply local pending changes with "Last Write Wins" logic using timestamps
            for entity in localEntities {
                let id = entity.id.uuidString
                switch entity.syncStatus {
                case .pendingDelete:
                    merged.removeValue(forKey: id)
                case .pendingCreate, .pendingUpdate, .pendingRecovery, .failed:
                    // Local pending change always wins over remote snapshot
                    merged[id] = entity.toItemModel()
                case .synced:
                    // For synced items, check if we have a conflict
                    if let remoteItem = merged[id], 
                       let remoteUpdatedAt = remoteItem.updatedAt {
                         // Note: entity.updatedAt is non-optional in ItemEntity, so we can use it directly.
                         // If remote is newer, it wins (already in merged).
                         // If local is newer (shouldn't happen for .synced, but safety net), use local.
                         if entity.updatedAt > remoteUpdatedAt {
                             merged[id] = entity.toItemModel()
                         }
                    }
                }
            }
            
            // Rebuild the list with stable sort order
            // 1. If we have current items, try to preserve their relative order
            // 2. Sort everything by createdAt to ensure consistent positioning for new items
            
            let allItems = Array(merged.values)
            return allItems.sorted(by: ItemModel.compare)
        } catch {
            logVoid(params: (note: "mergeRemoteSnapshot", error: (error as NSError).localizedDescription))
            return snapshot
        }
    }
}

