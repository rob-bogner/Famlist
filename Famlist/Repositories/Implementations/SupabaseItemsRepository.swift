/*
 SupabaseItemsRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-backed implementation of ItemsRepository.
 - Core class: dependencies, Realtime observation, fetchAndYield.
 - CRUD operations live in SupabaseItemsRepository+CRUD.swift.
 - Suppression state is encapsulated in RealtimeGate.swift.

 🛠 Includes:
 - observeItems: AsyncStream backed by Realtime subscriptions.
 - processRealtimeEvent: routes INSERT/UPDATE/DELETE to RealtimeEventProcessor.
 - fetchAndYield: fetches all items for a list and broadcasts to observers.

 🔰 Notes for Beginners:
 - Refactored from a 644-line monolith (FAM-67).
 - @MainActor isolation prevents Data Races on all mutable state.

 📝 Last Change:
 - FAM-67: split into RealtimeGate + SupabaseItemsRepository + SupabaseItemsRepository+CRUD.
 ------------------------------------------------------------------------
*/

import Foundation
import Supabase

/// Supabase-backed items repository implementing ItemsRepository.
/// @MainActor ensures that all mutable properties (continuations, gate) are
/// accessed exclusively on the main thread, preventing Data Races.
@MainActor
final class SupabaseItemsRepository: ItemsRepository {

    // MARK: - Dependencies

    let client: SupabaseClienting
    private let realtimeManager: SupabaseRealtimeManager
    private let eventProcessor: RealtimeEventProcessor

    /// Suppression gate shared between the observation and CRUD layers.
    let gate: RealtimeGate

    // MARK: - State

    /// Active continuations keyed by listId → unique observer token.
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]

    // MARK: - Lifecycle

    init(client: SupabaseClienting, itemStore: SwiftDataItemStore, conflictResolver: ConflictResolver) {
        self.client = client
        self.realtimeManager = SupabaseRealtimeManager(client: client)
        self.eventProcessor = RealtimeEventProcessor(conflictResolver: conflictResolver, itemStore: itemStore)
        self.gate = RealtimeGate()
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

            Task {
                await self.fetchAndYield(listId)
            }
        }
        return logResult(params: ["listId": listId], result: stream)
    }

    private func yield(_ listId: UUID, _ items: [ItemModel]) {
        continuations[listId]?.values.forEach { $0.yield(items) }
    }

    /// Routes a Realtime event to the event processor, respecting suppression state.
    func processRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
        // Crash-recovery: clear a stale lock before checking suppression.
        let staleCleared = gate.checkAndClearStaleLock()
        if staleCleared {
            logVoid(params: (action: "processRealtimeEvent.staleLockRecovered", listId: listId))
        }

        // EVENT COUNTER: decrement for batch-triggered updates; skip further processing.
        if gate.isSuppressing && gate.expectedEvents > 0 {
            if case .update = event {
                gate.decrementEventCounter(for: listId)
            }
            logVoid(params: (
                action: "processRealtimeEvent.skipped",
                reason: "waitingForBatchEvents",
                listId: listId
            ))
            return
        }

        // PESSIMISTIC LOCK: ignore all Realtime events during bulk operations.
        if gate.isSuppressing {
            logVoid(params: (
                action: "processRealtimeEvent.skipped",
                reason: "batchOperationInProgress",
                listId: listId
            ))
            return
        }

        switch event {
        case .insert(let payload):
            await eventProcessor.processInsertion(payload, listId: listId)
        case .update(let payload):
            await eventProcessor.processUpdate(payload, listId: listId)
        case .delete(let payload):
            await eventProcessor.processDeletion(payload, listId: listId)
        }

        await fetchAndYield(listId)
    }

    /// Fetches all live items for a list from Supabase and broadcasts them to observers.
    func fetchAndYield(_ listId: UUID) async {
        struct Row: Codable {
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
        }
        do {
            let rows: [Row] = try await client
                .from("items")
                .select()
                .eq("list_id", value: listId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            let mapped = rows.map { r in
                ItemModel(
                    id: r.id.uuidString,
                    imageUrl: nil,
                    imageData: r.imageData,
                    name: r.name,
                    units: r.units,
                    measure: r.measure,
                    price: r.price,
                    isChecked: r.isChecked,
                    category: r.category,
                    productDescription: r.productDescription,
                    brand: r.brand,
                    listId: r.listId.uuidString,
                    ownerPublicId: r.ownerPublicId,
                    hlcTimestamp: r.hlcTimestamp,
                    hlcCounter: r.hlcCounter,
                    hlcNodeId: r.hlcNodeId,
                    tombstone: r.tombstone,
                    lastModifiedBy: r.lastModifiedBy
                )
            }
            yield(listId, mapped)
            logVoid(params: (listId: listId, itemsCount: mapped.count))
        } catch {
            logVoid(params: (
                listId: listId,
                note: "fetchError",
                error: String(describing: error)
            ))
        }
    }
}
