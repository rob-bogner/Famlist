/*
 SupabaseItemsRepository+CRUD.swift
 Famlist
 Created on: 15.03.2026

 📄 CRUD extension for SupabaseItemsRepository (extracted FAM-67).
 📝 Single ItemRow struct used for both upsert and update – eliminates
    payload duplication (FAM-73).

 CHANGELOG:
 - 16.03.2026: FAM-72 – MeasureCanonicalizer.canonicalize() in createItem,
               updateItem, batchUpdateItems (Defense in depth).
 - 16.03.2026: FAM-73 – ItemUpdatePayload entfernt; ItemRow für alle Writes
               genutzt. Custom encode(to:) schützt CRDT-Felder via encodeIfPresent.
*/

import Foundation
import Supabase

// MARK: - Private Row Types

/// Single Codable payload used for both upsert (createItem) and update operations.
///
/// **Encoding rules (FAM-73):**
/// - Regular mutable fields (imageData, category, etc.) use `encode` so that an explicit nil
///   clears the column — intentional user action (e.g. removing a photo).
/// - CRDT fields use `encodeIfPresent` to never accidentally overwrite existing metadata with null.
/// - Identity fields (id, listId) are always encoded; including them in UPDATE payloads is safe
///   in PostgREST because the WHERE filter matches the same values.
/// Minimal payload for tombstone-setting a single item (FAM-24 canonical delete).
private struct TombstonePayload: Encodable {
    let tombstone = true
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case tombstone
        case updatedAt = "updated_at"
    }

    /// Creates a payload with the current UTC timestamp in ISO8601 format.
    static func now() -> TombstonePayload {
        TombstonePayload(updatedAt: PaginationCursor.postgrestFormatter.string(from: Date()))
    }
}

private struct ItemRow: Encodable {
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
        case hlcTimestamp = "hlc_timestamp"
        case hlcCounter = "hlc_counter"
        case hlcNodeId = "hlc_node_id"
        case tombstone
        case lastModifiedBy = "last_modified_by"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(listId, forKey: .listId)
        try container.encodeIfPresent(ownerPublicId, forKey: .ownerPublicId)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(name, forKey: .name)
        try container.encode(units, forKey: .units)
        try container.encode(measure, forKey: .measure)
        try container.encode(price, forKey: .price)
        try container.encode(isChecked, forKey: .isChecked)
        try container.encode(category, forKey: .category)
        try container.encode(productDescription, forKey: .productDescription)
        try container.encode(brand, forKey: .brand)
        try container.encodeIfPresent(hlcTimestamp, forKey: .hlcTimestamp)
        try container.encodeIfPresent(hlcCounter, forKey: .hlcCounter)
        try container.encodeIfPresent(hlcNodeId, forKey: .hlcNodeId)
        try container.encodeIfPresent(tombstone, forKey: .tombstone)
        try container.encodeIfPresent(lastModifiedBy, forKey: .lastModifiedBy)
    }
}

// MARK: - CRUD Extension

extension SupabaseItemsRepository {

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
        // FAM-72: Defense in depth – normalize measure regardless of caller
        let canonicalMeasure = MeasureCanonicalizer.canonicalize(item.measure)
        let row = ItemRow(
            id: UUID(uuidString: item.id) ?? UUID(),
            listId: listUUID,
            ownerPublicId: item.ownerPublicId,
            imageData: item.imageData,
            name: item.name,
            units: item.units,
            measure: canonicalMeasure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand,
            hlcTimestamp: item.hlcTimestamp,
            hlcCounter: item.hlcCounter,
            hlcNodeId: item.hlcNodeId,
            tombstone: item.tombstone,
            lastModifiedBy: item.lastModifiedBy
        )
        // Upsert instead of insert: if the UUID already exists on the server (concurrent
        // creation on another device), the DB accepts the last writer's payload at the
        // storage layer. The HLC embedded in the row ensures that the subsequent Realtime
        // event is correctly arbitrated by ConflictResolver on every observing device.
        _ = try await client.from("items").upsert(row, onConflict: "id").execute()
        // FAM-24: No fetchAndYield() here. Local state was already written via storeLocally().
        // Realtime INSERT event will trigger granular processing via RealtimeEventProcessor.
        let model = ItemModel(
            id: row.id.uuidString,
            imageUrl: item.imageUrl,
            imageData: item.imageData,
            name: item.name,
            units: item.units,
            measure: canonicalMeasure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand,
            listId: listUUID.uuidString,
            ownerPublicId: item.ownerPublicId,
            hlcTimestamp: item.hlcTimestamp,
            hlcCounter: item.hlcCounter,
            hlcNodeId: item.hlcNodeId,
            tombstone: item.tombstone,
            lastModifiedBy: item.lastModifiedBy
        )
        let result = logResult(params: (itemId: model.id, listId: listUUID), result: model)
        return result
    }

    func updateItem(_ item: ItemModel) async throws {
        guard let listIdString = item.listId else {
            throw NSError(
                domain: "SupabaseItemsRepository",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Item update requires valid listId"]
            )
        }
        let listId = UUID(uuidString: listIdString) ?? UUID()
        // FAM-72: Defense in depth – normalize measure regardless of caller
        let canonicalMeasure = MeasureCanonicalizer.canonicalize(item.measure)
        let payload = ItemRow(
            id: UUID(uuidString: item.id) ?? UUID(),
            listId: listId,
            ownerPublicId: item.ownerPublicId,
            imageData: item.imageData,
            name: item.name,
            units: item.units,
            measure: canonicalMeasure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand,
            hlcTimestamp: item.hlcTimestamp,
            hlcCounter: item.hlcCounter,
            hlcNodeId: item.hlcNodeId,
            tombstone: item.tombstone,
            lastModifiedBy: item.lastModifiedBy
        )
        _ = try await client
            .from("items")
            .update(payload)
            .eq("id", value: item.id)
            .eq("list_id", value: listIdString)
            .execute()
        // FAM-24: No fetchAndYield() here. Local state was already written via storeLocally().
        // Realtime UPDATE event will trigger granular processing via RealtimeEventProcessor.
        logVoid(params: (itemId: item.id, listId: listId))
    }

    /// Batch-updates items in parallel using the event-counter strategy.
    /// Gate lock suppresses Realtime fetches; timeout provides fallback; final fetch ensures consistency.
    func batchUpdateItems(_ items: [ItemModel], listId: UUID) async throws {
        guard !items.isEmpty else { return }

        logVoid(params: (action: "batchUpdateItems.start", itemCount: items.count, listId: listId))

        // Acquire lock: suppress Realtime fetches during batch and set event counter.
        gate.acquireLock(expecting: items.count)
        logVoid(params: (action: "batchUpdateItems.suppressionEnabled", expectedEvents: items.count, listId: listId))

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in items {
                    group.addTask {
                        guard let listIdForItem = item.listId,
                              let listUUID = UUID(uuidString: listIdForItem) else {
                            throw NSError(
                                domain: "SupabaseItemsRepository",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "Missing list_id"]
                            )
                        }
                        // FAM-72: Defense in depth – normalize measure regardless of caller
                        let payload = ItemRow(
                            id: UUID(uuidString: item.id) ?? UUID(),
                            listId: listUUID,
                            ownerPublicId: item.ownerPublicId,
                            imageData: item.imageData,
                            name: item.name,
                            units: item.units,
                            measure: MeasureCanonicalizer.canonicalize(item.measure),
                            price: item.price,
                            isChecked: item.isChecked,
                            category: item.category,
                            productDescription: item.productDescription,
                            brand: item.brand,
                            hlcTimestamp: item.hlcTimestamp,
                            hlcCounter: item.hlcCounter,
                            hlcNodeId: item.hlcNodeId,
                            tombstone: item.tombstone,
                            lastModifiedBy: item.lastModifiedBy
                        )
                        _ = try await self.client
                            .from("items")
                            .update(payload)
                            .eq("id", value: item.id)
                            .eq("list_id", value: listUUID.uuidString)
                            .execute()
                    }
                }
                try await group.waitForAll()
            }

            // Start timeout task: releases lock if Realtime events don't arrive in time.
            let timeoutTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(gate.eventCounterTimeout * 1_000_000_000))
                if gate.isSuppressing {
                    let remaining = gate.expectedEvents
                    gate.releaseLock()
                    logVoid(params: (
                        action: "batchUpdateItems.suppressionDisabled.timeout",
                        reason: "Timeout reached with \(remaining) events still pending",
                        listId: listId
                    ))
                }
            }

            // Poll until gate is released (by event counter) or timeout fires.
            let startTime = Date()
            while gate.isSuppressing {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
                if Date().timeIntervalSince(startTime) > gate.eventCounterTimeout + 0.5 { break }
            }

            timeoutTask.cancel()

            // Ensure lock is released (may already be released by counter or timeout).
            if gate.isSuppressing {
                gate.releaseLock()
                logVoid(params: (action: "batchUpdateItems.suppressionDisabled.manual", listId: listId))
            }

            // FAM-24: No fetchAndYield() here. Realtime UPDATE events will trigger
            // granular processing via RealtimeEventProcessor for each item.

        } catch {
            // Release lock on error to restore Realtime processing.
            gate.releaseLock()
            logVoid(params: (
                action: "batchUpdateItems.suppressionDisabled.error",
                listId: listId,
                error: error.localizedDescription
            ))
            throw error
        }

        logVoid(params: (action: "batchUpdateItems.completed", itemCount: items.count, listId: listId))
    }

    /// Deletes an item by setting tombstone=true (soft delete per FAM-24 architecture).
    /// The Realtime UPDATE event (tombstone=true) triggers applyRemoteTombstone() on all observers.
    /// Physical row purge is a server-side retention concern, not a client operation.
    func deleteItem(id: String, listId: UUID) async throws {
        _ = try await client
            .from("items")
            .update(TombstonePayload.now())
            .eq("id", value: id)
            .eq("list_id", value: listId.uuidString)
            .execute()
        // FAM-24: No fetchAndYield() here. Realtime UPDATE(tombstone=true) event
        // will trigger applyRemoteTombstone() via RealtimeEventProcessor.
        logVoid(params: (id: id, listId: listId))
    }
}
