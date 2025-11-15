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
            let currentIds = Set(currentItems.map { $0.id })
            
            // First, keep all existing items in their current order (updated with new data)
            for existingItem in currentItems {
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
            
            if !merged.isEmpty {
                ordered.append(contentsOf: merged.values)
            }
            return ordered
        } catch {
            logVoid(params: (note: "mergeRemoteSnapshot", error: (error as NSError).localizedDescription))
            return snapshot
        }
    }
}

