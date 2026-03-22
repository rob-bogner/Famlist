/*
 SupabaseItemsRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-backed implementation of ItemsRepository.
 - Core class: dependencies, Realtime observation, fetchAndYield, pagination, incremental sync.
 - CRUD operations live in SupabaseItemsRepository+CRUD.swift.
 - Echo protection via ItemEntity.hasPendingLocalChange (no RealtimeGate needed).

 🛠 Includes:
 - observeItems: AsyncStream backed by Realtime subscriptions.
 - processRealtimeEvent: routes INSERT/UPDATE/DELETE to RealtimeEventProcessor; no full refetch.
 - fetchAndYield: full remote fetch (App-Start / Pull-to-Refresh only).
 - fetchItems(cursor:limit:): composite-cursor paged fetch (FAM-79).
 - fetchItemsSince(since:): delta fetch for IncrementalSync (FAM-41).
 - refreshLocalAndYield: reads from SwiftData and yields to stream observers.

 🔰 Notes for Beginners:
 - Realtime events are processed granularly; fetchAndYield is no longer called after every event.
 - SyncOrchestrator buffers Realtime handlers during active page loads (FAM-79).

 📝 Last Change:
 - FAM-79/FAM-41: Granular Realtime, composite-cursor pagination, incremental sync.
 ------------------------------------------------------------------------
*/

import Foundation
import Supabase

// MARK: - Shared Row Type

/// Shared Codable struct for mapping Supabase rows to ItemModel.
/// Extracted from fetchAndYield() so it can be reused by fetchItems() and fetchItemsSince().
private struct ItemRow: Codable {
    let id: UUID
    let listId: UUID
    let ownerPublicId: String?
    let imageData: String?
    let name: String
    let units: Int
    let measure: String
    let price: Double
    let isChecked: Bool
    let category: String?
    let productDescription: String?
    let brand: String?
    let createdAt: String?
    let updatedAt: String?
    let hlcTimestamp: Int64?
    let hlcCounter: Int?
    let hlcNodeId: String?
    let tombstone: Bool?
    let lastModifiedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case ownerPublicId = "ownerpublicid"
        case imageData = "imagedata"
        case name, units, measure, price, isChecked, category
        case productDescription = "productdescription"
        case brand
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hlcTimestamp = "hlc_timestamp"
        case hlcCounter = "hlc_counter"
        case hlcNodeId = "hlc_node_id"
        case tombstone
        case lastModifiedBy = "last_modified_by"
    }

    func toItemModel() -> ItemModel {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterBasic = ISO8601DateFormatter()

        func parseDate(_ str: String?) -> Date? {
            guard let str else { return nil }
            return isoFormatter.date(from: str) ?? isoFormatterBasic.date(from: str)
        }

        return ItemModel(
            id: id.uuidString,
            imageUrl: nil,
            imageData: imageData,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId.uuidString,
            ownerPublicId: ownerPublicId,
            createdAt: parseDate(createdAt),
            updatedAt: parseDate(updatedAt),
            hlcTimestamp: hlcTimestamp,
            hlcCounter: hlcCounter,
            hlcNodeId: hlcNodeId,
            tombstone: tombstone,
            lastModifiedBy: lastModifiedBy
        )
    }
}

// MARK: - SupabaseItemsRepository

/// Supabase-backed items repository implementing ItemsRepository.
/// @MainActor ensures that all mutable properties (continuations, gate) are
/// accessed exclusively on the main thread, preventing Data Races.
@MainActor
final class SupabaseItemsRepository: ItemsRepository {

    // MARK: - Dependencies

    let client: SupabaseClienting
    private let realtimeManager: SupabaseRealtimeManager
    private let eventProcessor: RealtimeEventProcessor

    /// Local SwiftData store — used to yield locally-sourced snapshots after Realtime events.
    private let itemStore: SwiftDataItemStore

    /// Orchestrator that serialises PageLoader and Realtime event processing.
    /// Optional for backward compatibility (nil in tests that don't inject it).
    var syncOrchestrator: SyncOrchestrator?

    // MARK: - State

    /// Active continuations keyed by listId → unique observer token.
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]


    // MARK: - Lifecycle

    init(
        client: SupabaseClienting,
        itemStore: SwiftDataItemStore,
        conflictResolver: ConflictResolver,
        syncOrchestrator: SyncOrchestrator? = nil
    ) {
        self.client = client
        self.itemStore = itemStore
        self.realtimeManager = SupabaseRealtimeManager(client: client)
        self.eventProcessor = RealtimeEventProcessor(conflictResolver: conflictResolver, itemStore: itemStore)
        self.syncOrchestrator = syncOrchestrator
    }

    // MARK: - Observation

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        let stream = AsyncStream { continuation in
            let token = UUID()
            if continuations[listId] == nil {
                continuations[listId] = [:]
            }
            continuations[listId]?[token] = continuation

            // Set up Realtime subscription if this is the first observer for this list.
            if self.continuations[listId]?.count == 1 {
                Task {
                    await self.realtimeManager.setupRealtimeChannel(for: listId) { [weak self] event in
                        await self?.processRealtimeEvent(event, listId: listId)
                    }
                }
            }

            // onTermination can be called on any thread; dispatch back to MainActor.
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.continuations[listId]?.removeValue(forKey: token)
                    if self.continuations[listId]?.isEmpty == true {
                        self.realtimeManager.teardownRealtimeChannel(for: listId)
                        self.continuations.removeValue(forKey: listId)
                    }
                }
            }
            // Note: No initial fetchAndYield() here (FAM-41).
            // Initial data is provided by loadLocalSnapshot() + runIncrementalSync() in ListViewModel.
        }
        return logResult(params: ["listId": listId], result: stream)
    }

    private func yield(_ listId: UUID, _ items: [ItemModel]) {
        continuations[listId]?.values.forEach { $0.yield(items) }
    }

    // MARK: - Realtime Event Processing

    /// Routes a Realtime event to the event processor, respecting SyncOrchestrator buffering.
    /// Echo protection for bulk operations is handled by `ItemEntity.hasPendingLocalChange`
    /// in `RealtimeEventProcessor.processUpdate()` — no RealtimeGate needed.
    func processRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
        // Extract a stable item id for SyncOrchestrator coalescing.
        let itemId = extractItemId(from: event) ?? UUID().uuidString

        // SyncOrchestrator: buffer during page loads, process immediately otherwise.
        if let orchestrator = syncOrchestrator {
            await orchestrator.enqueueOrProcess(itemId: itemId) { [weak self] in
                await self?.handleRealtimeEvent(event, listId: listId)
            }
        } else {
            await handleRealtimeEvent(event, listId: listId)
        }
    }

    /// Processes a Realtime event and yields the updated local snapshot to stream observers.
    private func handleRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
        switch event {
        case .insert(let payload):
            await eventProcessor.processInsertion(payload, listId: listId)
        case .update(let payload):
            await eventProcessor.processUpdate(payload, listId: listId)
        case .delete(let payload):
            await eventProcessor.processDeletion(payload, listId: listId)
        }

        // FAM-41: yield from SwiftData (local truth), not from a full remote refetch.
        refreshLocalAndYield(listId)
    }

    /// Reads the current list from SwiftData and yields it to all stream observers for this list.
    func refreshLocalAndYield(_ listId: UUID) {
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            yield(listId, localItems)
            logVoid(params: (action: "refreshLocalAndYield", listId: listId, count: localItems.count))
        } catch {
            logVoid(params: (action: "refreshLocalAndYield.error", listId: listId, error: error.localizedDescription))
        }
    }

    // MARK: - Full Fetch (App-Start / Pull-to-Refresh)

    /// Fetches all live items for a list from Supabase and broadcasts them to observers.
    /// Called only on App-Start and Pull-to-Refresh — not after individual Realtime events (FAM-41).
    ///
    /// - Note: Tombstoned items (soft-deleted remotely) are excluded via the PostgREST filter.
    ///   This prevents purged items from reappearing in the UI if this method is ever called.
    ///   The main pull-to-refresh path uses runIncrementalSync() which handles tombstones
    ///   via applyRemoteTombstoneModel(). This function is retained as a defensive fallback.
    func fetchAndYield(_ listId: UUID) async {
        do {
            let rows: [ItemRow] = try await client
                .from("items")
                .select()
                .eq("list_id", value: listId.uuidString)
                .or("tombstone.is.false,tombstone.is.null")
                .order("created_at", ascending: true)
                .execute()
                .value
            let mapped = rows.map { $0.toItemModel() }
            yield(listId, mapped)
            logVoid(params: (listId: listId, itemsCount: mapped.count))
        } catch {
            logVoid(params: (
                listId: listId,
                note: "fetchAndYield.error",
                error: String(describing: error)
            ))
        }
    }

    // MARK: - Pagination (FAM-79)

    /// Fetches a page of non-tombstoned items sorted by (created_at ASC, id ASC) using a composite cursor.
    /// Items are returned for caller upsert — this method does NOT upsert into SwiftData itself.
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] {
        var query = client
            .from("items")
            .select()
            .eq("list_id", value: listId.uuidString)
            .or("tombstone.is.false,tombstone.is.null")

        if let cursor {
            let isoDate = cursor.createdAtISO
            let uuidStr = cursor.id.uuidString.lowercased()
            query = query.or("created_at.gt.\(isoDate),and(created_at.eq.\(isoDate),id.gt.\(uuidStr))")
        }

        let rows: [ItemRow] = try await query
            .order("created_at", ascending: true)
            .order("id", ascending: true)
            .limit(limit)
            .execute()
            .value

        return rows.map { $0.toItemModel() }
    }

    // MARK: - Incremental Sync (FAM-41)

    /// Fetches items (including tombstoned) whose updated_at is strictly after `since`.
    /// Used by IncrementalSync to pull only changes since the last successful sync.
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        let sinceISO = PaginationCursor.postgrestFormatter.string(from: since)

        let rows: [ItemRow] = try await client
            .from("items")
            .select()
            .eq("list_id", value: listId.uuidString)
            .gt("updated_at", value: sinceISO)
            .order("updated_at", ascending: true)
            .execute()
            .value

        return rows.map { $0.toItemModel() }
    }

    // MARK: - Helpers

    /// Extracts the item id string from a Realtime event payload for SyncOrchestrator coalescing.
    private func extractItemId(from event: RealtimeEvent) -> String? {
        func extractFromPayload(_ payload: [String: Any]) -> String? {
            let record = (payload["record"] as? [String: Any]) ?? (payload["old_record"] as? [String: Any])
            return record?["id"] as? String
        }
        switch event {
        case .insert(let p), .update(let p), .delete(let p):
            return extractFromPayload(p)
        }
    }
}
