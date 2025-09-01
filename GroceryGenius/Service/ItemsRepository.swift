// MARK: - ItemsRepository.swift

/*
 File: ItemsRepository.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 01.09.2025

 Overview:
 Async/await repository contract for Items stored in Supabase (Postgres + Storage).
 Also provides an in-memory PreviewItemsRepository for SwiftUI previews and offline UI testing.
*/

import Foundation

// MARK: - Protocol (Async/Await)

protocol ItemsRepository {
    /// Observe items for a given list id. Implementation may use Supabase Realtime or polling.
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]>
    /// Create a new item; may upload image to storage and store URL in DB.
    func createItem(_ item: ItemModel) async throws -> ItemModel
    /// Update an existing item.
    func updateItem(_ item: ItemModel) async throws
    /// Delete an item by id within list.
    func deleteItem(id: String, listId: UUID) async throws
}

// MARK: - Preview/In-Memory Implementation

final class PreviewItemsRepository: ItemsRepository {
    private var storage: [UUID: [ItemModel]] = [:]
    // Track continuations by UUID token because Continuation is a struct (no identity)
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        AsyncStream { continuation in
            let token = UUID()
            if continuations[listId] == nil { continuations[listId] = [:] }
            continuations[listId]?[token] = continuation
            continuation.onTermination = { _ in
                self.continuations[listId]?.removeValue(forKey: token)
            }
            continuation.yield(storage[listId] ?? [])
        }
    }

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
        var arr = storage[listUUID] ?? []
        var new = item
        if new.listId == nil { new.listId = listUUID.uuidString }
        arr.append(new)
        storage[listUUID] = arr
        broadcast(listUUID)
        return new
    }

    func updateItem(_ item: ItemModel) async throws {
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
        guard var arr = storage[listUUID] else { return }
        if let idx = arr.firstIndex(where: { $0.id == item.id }) {
            arr[idx] = item
        }
        storage[listUUID] = arr
        broadcast(listUUID)
    }

    func deleteItem(id: String, listId: UUID) async throws {
        guard var arr = storage[listId] else { return }
        arr.removeAll { $0.id == id }
        storage[listId] = arr
        broadcast(listId)
    }

    private func broadcast(_ listId: UUID) {
        let arr = storage[listId] ?? []
        continuations[listId]?.values.forEach { $0.yield(arr) }
    }
}
