/*
 ItemsRepository.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Async/await repository contract for Items stored in Supabase (Postgres + Storage) plus an in-memory PreviewItemsRepository for previews.

 🛠 Includes:
 - ItemsRepository protocol (observe/create/update/delete) and PreviewItemsRepository implementation.

 🔰 Notes for Beginners:
 - The protocol allows swapping the data source (real Supabase vs. preview memory store).
 - AsyncStream publishes live updates; SwiftUI lists update automatically when data changes.

 📝 Last Change:
 - Standardized header and expanded inline comments; no functional changes.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID, AsyncStream, and base types used here.

// MARK: - Protocol (Async/Await)

/// Contract describing how to load and mutate shopping list items regardless of the backend implementation.
/// Conforming types can provide network-backed (Supabase) or in-memory (preview) behavior.
protocol ItemsRepository { // Protocol ensures the app can switch data sources without touching UI code.
    /// Observe items for a given list id. Implementation may use Supabase Realtime or polling.
    /// - Parameter listId: The list UUID to scope items to.
    /// - Returns: An AsyncStream emitting arrays of ItemModel whenever the underlying data changes.
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> // Stream of live item snapshots.
    /// Create a new item; may upload image to storage and store URL in DB.
    /// - Parameter item: The item to create.
    /// - Returns: The created item (possibly with server-set fields filled).
    func createItem(_ item: ItemModel) async throws -> ItemModel // Async create operation.
    /// Update an existing item.
    /// - Parameter item: The full item to persist (identified by its id).
    func updateItem(_ item: ItemModel) async throws // Async update operation.
    /// Batch update multiple items (optimized for bulk operations).
    /// - Parameters:
    ///   - items: Array of items to update.
    ///   - listId: The list that the items belong to.
    /// - Note: Only triggers a single fetch after all updates complete.
    func batchUpdateItems(_ items: [ItemModel], listId: UUID) async throws // Async batch update operation.
    /// Delete an item by id within list.
    /// - Parameters:
    ///   - id: The item identifier to delete.
    ///   - listId: The list that the item belongs to (used to scope deletion and updates in streams).
    func deleteItem(id: String, listId: UUID) async throws // Async delete operation.
}

// MARK: - Preview/In-Memory Implementation

/// Simple in-memory repository used for SwiftUI previews and offline demos.
/// Stores items in a dictionary keyed by list UUID and broadcasts changes through AsyncStream continuations.
final class PreviewItemsRepository: ItemsRepository { // Final prevents subclassing; this is a simple utility type.
    private var storage: [UUID: [ItemModel]] = [:] // In-memory store mapping list IDs to their items.
    // Track continuations by UUID token because Continuation is a struct (no identity)
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:] // Active subscribers per list.

    /// Starts observing items for the given list id.
    /// - Parameter listId: The list whose items should be streamed.
    /// - Returns: An AsyncStream emitting arrays whenever storage changes for that list.
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { // Creates an AsyncStream and stores its continuation to push updates later.
        AsyncStream { continuation in // Builder closure provides a continuation handle to send values to the stream.
            let token = UUID() // Unique token to identify this subscriber for cleanup.
            if continuations[listId] == nil { continuations[listId] = [:] } // Ensure an entry exists for this list.
            continuations[listId]?[token] = continuation // Save continuation so we can yield updates later.
            continuation.onTermination = { _ in // Called when the observer cancels or stream finishes.
                self.continuations[listId]?.removeValue(forKey: token) // Remove the continuation to avoid memory leaks.
            }
            continuation.yield(storage[listId] ?? []) // Immediately send current snapshot so UI has initial data.
        }
    }

    /// Inserts a new item into the in-memory storage and broadcasts the change.
    /// - Parameter item: The item to create.
    /// - Returns: The item as stored (listId may be injected if missing).
    func createItem(_ item: ItemModel) async throws -> ItemModel { // Mimics async behavior for parity with real repo.
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID() // Resolve list UUID from item's listId string or fallback to a random one.
        var arr = storage[listUUID] ?? [] // Fetch current items for list or start with empty array.
        var new = item // Make a mutable copy to set listId if needed.
        if new.listId == nil { new.listId = listUUID.uuidString } // Ensure item carries the list id for future updates.
        arr.append(new) // Append to list items.
        storage[listUUID] = arr // Save back into storage.
        broadcast(listUUID) // Notify observers about the change.
        return new // Return the stored item.
    }

    /// Updates an existing item in storage and notifies observers.
    /// - Parameter item: The full replacement item to store (matched by id).
    func updateItem(_ item: ItemModel) async throws { // Async signature for symmetry with real repo.
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID() // Determine which list this item belongs to.
        guard var arr = storage[listUUID] else { return } // If list has no items recorded yet, nothing to update.
        if let idx = arr.firstIndex(where: { $0.id == item.id }) { // Find the index of the item by id.
            arr[idx] = item // Replace the existing item with the updated one.
        }
        storage[listUUID] = arr // Persist updated array back to storage.
        broadcast(listUUID) // Notify observers so UI refreshes.
    }
    
    /// Batch updates multiple items in storage and notifies observers once.
    /// - Parameters:
    ///   - items: Array of items to update.
    ///   - listId: The list that the items belong to.
    func batchUpdateItems(_ items: [ItemModel], listId: UUID) async throws { // Batch update for efficiency.
        guard var arr = storage[listId] else { return } // If list has no items recorded yet, nothing to update.
        for item in items { // Update each item in the batch.
            if let idx = arr.firstIndex(where: { $0.id == item.id }) { // Find the index of the item by id.
                arr[idx] = item // Replace the existing item with the updated one.
            }
        }
        storage[listId] = arr // Persist updated array back to storage once.
        broadcast(listId) // Notify observers so UI refreshes (single notification).
    }

    /// Deletes an item by id from the specified list and broadcasts the new snapshot.
    /// - Parameters:
    ///   - id: The identifier of the item to remove.
    ///   - listId: The list to remove the item from.
    func deleteItem(id: String, listId: UUID) async throws { // Async signature to match protocol.
        guard var arr = storage[listId] else { return } // If nothing stored for this list, nothing to delete.
        arr.removeAll { $0.id == id } // Remove any item whose id matches.
        storage[listId] = arr // Save updated array back to storage.
        broadcast(listId) // Notify all observers of this list.
    }

    /// Sends the current array of items for a list to all active observers.
    /// - Parameter listId: The list whose snapshot should be emitted.
    private func broadcast(_ listId: UUID) { // Helper to yield new values to all saved continuations.
        let arr = storage[listId] ?? [] // Read current items or use empty array.
        continuations[listId]?.values.forEach { $0.yield(arr) } // Yield the array to each subscriber's continuation.
    }
}
