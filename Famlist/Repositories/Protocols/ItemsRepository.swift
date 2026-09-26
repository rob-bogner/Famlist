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
 - Einzelne Schreibmethoden durch upsertItems (HLC-geprüft, gebündelt) ersetzt (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID, AsyncStream, and base types used here.

// MARK: - Protocol (Async/Await)

/// Contract describing how to load and mutate shopping list items regardless of the backend implementation.
/// Conforming types can provide network-backed (Supabase) or in-memory (preview) behavior.
/// @MainActor stellt sicher, dass alle Conformances (inkl. PreviewItemsRepository) ohne Swift-6-Isolation-Fehler kompilieren.
@MainActor
protocol ItemsRepository { // Protocol ensures the app can switch data sources without touching UI code.
    /// Observe items for a given list id. Implementation may use Supabase Realtime or polling.
    /// - Parameter listId: The list UUID to scope items to.
    /// - Returns: An AsyncStream emitting arrays of ItemModel whenever the underlying data changes.
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> // Stream of live item snapshots.
    /// Schreibt Artikel (Anlegen, Ändern, Löschmarkierung) mit HLC-Prüfung auf dem Server
    /// (RPC upsert_items_lww, Migration 015). Höchstens 200 Aufträge pro Aufruf.
    /// Einziger Schreibweg für Artikel – alle Änderungen laufen über die SyncEngine hierher.
    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult]

    /// Wird aufgerufen, wenn der Realtime-Kanal einer Liste nach einem Abbruch wieder verbunden ist.
    /// Die Liste holt dann Verpasstes per Delta-Abgleich nach.
    func setReconnectHandler(_ handler: @escaping @MainActor (UUID) -> Void)

    // MARK: - Pagination & Incremental Sync (FAM-79 / FAM-41)

    /// Fetches a page of non-tombstoned items sorted by (created_at ASC, id ASC).
    /// Uses a composite cursor to guarantee no rows are skipped or duplicated even when
    /// multiple items share the same created_at timestamp.
    ///
    /// - Parameters:
    ///   - listId: List to scope the query.
    ///   - cursor: Composite cursor from the previous page. Nil loads from the beginning.
    ///   - limit: Maximum number of items to return.
    /// - Returns: Items for this page. Callers should upsert them into SwiftData.
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel]

    /// Fetches all items (including tombstoned) whose updated_at is strictly after `since`.
    /// Used by IncrementalSync to pull only the delta since the last successful sync.
    ///
    /// - Parameters:
    ///   - listId: List to scope the query.
    ///   - since: High-water mark timestamp. Items updated before or at this time are excluded.
    /// - Returns: Changed items (creates, updates, tombstones) since `since`.
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel]
    /// Alle Artikel-IDs einer Liste auf dem Server (Abgleich nach langer Pause). nil = nicht unterstützt.
    func fetchItemIds(listId: UUID) async throws -> Set<String>?
}

extension ItemsRepository {
    /// Standard: keine Realtime-Verbindung (Vorschau, Tests).
    func setReconnectHandler(_ handler: @escaping @MainActor (UUID) -> Void) {}
    /// Standard: kein Abgleich der ID-Menge.
    func fetchItemIds(listId: UUID) async throws -> Set<String>? { nil }
}

// MARK: - Preview/In-Memory Implementation

/// Simple in-memory repository used for SwiftUI previews and offline demos.
/// Stores items in a dictionary keyed by list UUID and broadcasts changes through AsyncStream continuations.
/// @MainActor durch Protokoll-Konformität (ItemsRepository ist @MainActor).
@MainActor
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
            continuation.onTermination = { @Sendable [weak self] _ in // Called when the observer cancels or stream finishes.
                Task { @MainActor [weak self] in
                    self?.continuations[listId]?.removeValue(forKey: token) // Remove the continuation to avoid memory leaks.
                }
            }
            continuation.yield(storage[listId] ?? []) // Immediately send current snapshot so UI has initial data.
        }
    }

    /// Übernimmt Aufträge nach derselben Regel wie der Server (neuere HLC gewinnt).
    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] {
        var touched = Set<UUID>()
        let results = requests.map { request -> ItemUpsertResult in
            let item = request.item
            let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
            touched.insert(listUUID)
            var arr = storage[listUUID] ?? []
            if let idx = arr.firstIndex(where: { $0.id == item.id }) {
                guard arr[idx].hlc < item.hlc else {
                    return ItemUpsertResult(id: item.id, status: .stale, item: arr[idx], message: nil)
                }
                var stored = item
                if !request.includeImage { stored.imageData = arr[idx].imageData }
                arr[idx] = stored
            } else {
                arr.append(item)
            }
            storage[listUUID] = arr
            return ItemUpsertResult(id: item.id, status: .applied, item: item, message: nil)
        }
        touched.forEach(broadcast)
        return results
    }

    /// Sends the current array of items for a list to all active observers.
    /// - Parameter listId: The list whose snapshot should be emitted.
    private func broadcast(_ listId: UUID) { // Helper to yield new values to all saved continuations.
        let arr = (storage[listId] ?? []).filter { $0.tombstone != true } // Löschmarkierte Artikel nicht zeigen.
        continuations[listId]?.values.forEach { $0.yield(arr) } // Yield the array to each subscriber's continuation.
    }

    // MARK: - Pagination & Incremental Sync (Preview Stubs)

    /// Returns the first `limit` non-tombstoned items after the given cursor (or from the start).
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] {
        let all = storage[listId] ?? []
        let live = all.filter { $0.tombstone != true }
        guard let cursor else {
            return Array(live.prefix(limit))
        }
        // Advance past cursor position using the same composite sort (created_at ASC, id ASC).
        let after = live.filter { item in
            guard let createdAt = item.createdAt else { return false }
            if createdAt > cursor.createdAt { return true }
            if createdAt == cursor.createdAt, item.id > cursor.id.uuidString { return true }
            return false
        }
        return Array(after.prefix(limit))
    }

    /// Returns items updated after `since` (delta for IncrementalSync).
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        let all = storage[listId] ?? []
        return all.filter { ($0.updatedAt ?? Date.distantPast) > since }
    }

    /// Alle IDs der Liste im Speicher (wie der Server: Löschmarkierungen zählen, solange sie da sind).
    func fetchItemIds(listId: UUID) async throws -> Set<String>? {
        Set((storage[listId] ?? []).map(\.id))
    }
}
