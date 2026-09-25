/*
 SupabaseItemsRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-backed implementation of ItemsRepository.
 - Core class: dependencies, Realtime observation, fetchAndYield, pagination, incremental sync.
 - Der einzige Schreibweg (upsertItems) liegt in SupabaseItemsRepository+CRUD.swift.

 🛠 Includes:
 - observeItems: AsyncStream backed by Realtime subscriptions.
 - processRealtimeEvent: routes INSERT/UPDATE/DELETE to RealtimeEventProcessor; no full refetch.
 - fetchItems(cursor:limit:): composite-cursor paged fetch (FAM-79).
 - fetchItemsSince(since:): delta fetch for IncrementalSync (FAM-41).
 - refreshLocalAndYield: reads from SwiftData and yields to stream observers.

 🔰 Notes for Beginners:
 - Realtime events are processed granularly; fetchAndYield is no longer called after every event.
 - SyncOrchestrator buffers Realtime handlers during active page loads (FAM-79).

 📝 Last Change:
 - RealtimeGate entfernt: Er verwarf während „Alle abhaken“ bis zu 5 s lang auch FREMDE Änderungen.
   Eigene Echos sind mit der HLC-Regel unschädlich (gleiche HLC → ignoriert). Delta-Abgleich
   lädt seitenweise statt unbegrenzt (Audit 25.09.2026).
 ------------------------------------------------------------------------
*/

import Foundation
import Supabase

// MARK: - Shared Row Type

/// Zeile der Tabelle items im PostgREST-Format (auch in der Antwort von upsert_items_lww).
struct SupabaseItemRow: Codable {
    let id: UUID
    let listId: UUID
    let ownerPublicId: String?
    let imageData: String?
    let imagePath: String?
    let name: String
    let units: Int
    let measure: String
    let price: Double
    let isChecked: Bool
    let isUnavailable: Bool? // nil until migration 005 is applied
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
        case imagePath = "image_path"
        case name, units, measure, price, isChecked, category
        case isUnavailable = "is_unavailable"
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
            imagePath: imagePath,
            imageData: imageData,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            isUnavailable: isUnavailable ?? false,
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

    /// Meldung „Realtime wieder verbunden“ an die Liste (Delta-Abgleich).
    private var reconnectHandler: (@MainActor (UUID) -> Void)?

    func setReconnectHandler(_ handler: @escaping @MainActor (UUID) -> Void) {
        reconnectHandler = handler
    }

    /// Active continuations keyed by listId → unique observer token.
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]

    // MARK: - Lifecycle

    init(
        client: SupabaseClienting,
        itemStore: SwiftDataItemStore,
        syncOrchestrator: SyncOrchestrator? = nil
    ) {
        self.client = client
        self.itemStore = itemStore
        self.realtimeManager = SupabaseRealtimeManager(client: client)
        self.eventProcessor = RealtimeEventProcessor(itemStore: itemStore)
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
                    await self.realtimeManager.setupRealtimeChannel(
                        for: listId,
                        onEvent: { [weak self] event in await self?.processRealtimeEvent(event, listId: listId) },
                        onResubscribed: { [weak self] in self?.reconnectHandler?(listId) }
                    )
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

        let rows: [SupabaseItemRow] = try await query
            .order("created_at", ascending: true)
            .order("id", ascending: true)
            .limit(limit)
            .execute()
            .value

        return rows.map { $0.toItemModel() }
    }

    // MARK: - Incremental Sync (FAM-41)

    /// Seitengröße des Delta-Abgleichs (PostgREST liefert ohne Limit höchstens `max_rows` Zeilen – ohne Hinweis).
    static let deltaPageSize = 500

    /// Fetches items (including tombstoned) whose updated_at is after `since`, seitenweise bis zum Ende.
    /// Folgeseiten nutzen einen Schlüssel-Cursor (updated_at, id) mit dem exakten Zeitstempel des Servers
    /// (Mikrosekunden), damit bei gleichen Zeitstempeln an der Seitengrenze keine Zeile verloren geht.
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        var result: [ItemModel] = []
        var cursor: (updatedAt: String, id: String)?
        while true {
            var query = client.from("items").select().eq("list_id", value: listId.uuidString)
            if let cursor {
                query = query.or("updated_at.gt.\(cursor.updatedAt),and(updated_at.eq.\(cursor.updatedAt),id.gt.\(cursor.id))")
            } else {
                query = query.gt("updated_at", value: PaginationCursor.postgrestFormatter.string(from: since))
            }
            let rows: [SupabaseItemRow] = try await query
                .order("updated_at", ascending: true)
                .order("id", ascending: true)
                .limit(Self.deltaPageSize)
                .execute()
                .value
            result += rows.map { $0.toItemModel() }
            guard rows.count == Self.deltaPageSize, let last = rows.last, let stamp = last.updatedAt else { break }
            cursor = (Self.filterSafeTimestamp(stamp), last.id.uuidString.lowercased())
        }
        return result
    }

    /// Postgres liefert „…+00:00“; ein „+“ im Filter würde als Leerzeichen gelesen. UTC → „Z“.
    static func filterSafeTimestamp(_ raw: String) -> String {
        raw.hasSuffix("+00:00") ? String(raw.dropLast(6)) + "Z" : raw
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
