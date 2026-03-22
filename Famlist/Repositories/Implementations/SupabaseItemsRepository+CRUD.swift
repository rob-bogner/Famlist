/*
 SupabaseItemsRepository+CRUD.swift
 Famlist
 Created on: 15.03.2026

 📄 CRUD extension for SupabaseItemsRepository (extracted FAM-67).
 📝 Single ItemRow struct used for both upsert and update – eliminates
    payload duplication (FAM-73).

 CHANGELOG:
 - 16.03.2026: FAM-72 – MeasureCanonicalizer.canonicalize() in createItem,
               updateItem (Defense in depth).
 - 16.03.2026: FAM-73 – ItemUpdatePayload entfernt; ItemRow für alle Writes
               genutzt. Custom encode(to:) schützt CRDT-Felder via encodeIfPresent.
 - 21.03.2026: P6/Schnitt B – BulkTogglePayload + bulkToggleItems() eingeführt.
               Ersetzt N parallele .update()-Calls durch einen einzigen
               upsert([N rows], onConflict: "id") Request. Schreibt nur die
               8 toggle-relevanten Felder; alle anderen Spalten bleiben unverändert.
               updated_at wird client-seitig gesetzt (kein DB-Trigger auf items).
 - 22.03.2026: batchUpdateItems() entfernt (toter Code seit Schnitt B).
               ItemRow um updated_at erweitert — IncrementalSync sieht jetzt
               alle Updates, nicht nur Tombstones und Creates.
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
    let updatedAt: String   // ISO8601 — set by client; no BEFORE UPDATE trigger on items table.

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
        case updatedAt = "updated_at"
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
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Bulk Toggle Payload

/// Minimal upsert payload for toggleAllItems(). Writes ONLY the fields that change
/// during a toggle operation; all other columns are left untouched on the server.
///
/// PostgreSQL upsert semantics (INSERT … ON CONFLICT DO UPDATE SET …) guarantee
/// that only the listed columns are overwritten. `created_at` is not in this struct
/// and will not be modified. `updated_at` is set client-side because the `items`
/// table has no BEFORE UPDATE trigger (unlike `item_catalog`).
private struct BulkTogglePayload: Encodable {
    let id: UUID
    let listId: UUID
    let isChecked: Bool
    let hlcTimestamp: Int64
    let hlcCounter: Int
    let hlcNodeId: String
    let lastModifiedBy: String
    let updatedAt: String   // ISO8601 — set by client; no BEFORE UPDATE trigger on items table.

    enum CodingKeys: String, CodingKey {
        case id
        case listId         = "list_id"
        case isChecked      = "is_checked"
        case hlcTimestamp   = "hlc_timestamp"
        case hlcCounter     = "hlc_counter"
        case hlcNodeId      = "hlc_node_id"
        case lastModifiedBy = "last_modified_by"
        case updatedAt      = "updated_at"
    }
}

// MARK: - Bulk Tombstone Payload

/// Minimal upsert payload for bulkDeleteItems(). Sets tombstone=true and writes
/// only the fields needed for CRDT conflict resolution; all other columns remain
/// untouched on the server (PostgreSQL UPDATE-column semantics).
private struct BulkTombstonePayload: Encodable {
    let id: UUID
    let listId: UUID
    let tombstone = true
    let hlcTimestamp: Int64
    let hlcCounter: Int
    let hlcNodeId: String
    let lastModifiedBy: String
    let updatedAt: String   // ISO8601 — set by client; no BEFORE UPDATE trigger on items table.

    enum CodingKeys: String, CodingKey {
        case id
        case listId         = "list_id"
        case tombstone
        case hlcTimestamp   = "hlc_timestamp"
        case hlcCounter     = "hlc_counter"
        case hlcNodeId      = "hlc_node_id"
        case lastModifiedBy = "last_modified_by"
        case updatedAt      = "updated_at"
    }
}

// MARK: - CRUD Extension

extension SupabaseItemsRepository {

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
        // FAM-72: Defense in depth – normalize measure regardless of caller
        let canonicalMeasure = MeasureCanonicalizer.canonicalize(item.measure)
        let now = PaginationCursor.postgrestFormatter.string(from: Date())
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
            lastModifiedBy: item.lastModifiedBy,
            updatedAt: now
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
        let now = PaginationCursor.postgrestFormatter.string(from: Date())
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
            lastModifiedBy: item.lastModifiedBy,
            updatedAt: now
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

    // MARK: - Bulk Toggle

    /// Upserts toggle-state for N items with a single PostgREST call.
    ///
    /// Only the 8 toggle-relevant columns are written; name, units, measure, image, tombstone, etc.
    /// remain untouched on the server (PostgreSQL UPDATE-column semantics).
    ///
    /// Echo protection: callers must ensure items are `.pendingUpdate` in SwiftData before calling.
    /// Realtime echos are rejected by `RealtimeEventProcessor.processUpdate()` via
    /// `entity.hasPendingLocalChange`. No RealtimeGate needed.
    func bulkToggleItems(_ items: [ItemModel], listId: UUID) async throws {
        guard !items.isEmpty else { return }

        logVoid(params: (action: "bulkToggleItems.start", itemCount: items.count, listId: listId))

        let now = PaginationCursor.postgrestFormatter.string(from: Date())
        let payloads: [BulkTogglePayload] = items.compactMap { item in
            guard let listUUID = UUID(uuidString: item.listId ?? ""),
                  let ts       = item.hlcTimestamp,
                  let counter  = item.hlcCounter,
                  let nodeId   = item.hlcNodeId,
                  let modifier = item.lastModifiedBy
            else {
                logVoid(params: (
                    action: "bulkToggleItems.payloadSkipped",
                    itemId: item.id,
                    reason: "missingHLCOrListId"
                ))
                return nil
            }
            return BulkTogglePayload(
                id: UUID(uuidString: item.id) ?? UUID(),
                listId: listUUID,
                isChecked: item.isChecked,
                hlcTimestamp: ts,
                hlcCounter: counter,
                hlcNodeId: nodeId,
                lastModifiedBy: modifier,
                updatedAt: now
            )
        }

        guard !payloads.isEmpty else {
            logVoid(params: (action: "bulkToggleItems.aborted", reason: "allPayloadsSkipped"))
            return
        }

        _ = try await client
            .from("items")
            .upsert(payloads, onConflict: "id")
            .execute()

        logVoid(params: (action: "bulkToggleItems.completed", itemCount: payloads.count, listId: listId))
    }

    // MARK: - Bulk Delete

    /// Upserts tombstone=true for N items with a single PostgREST call.
    ///
    /// Analogous to `bulkToggleItems()`: one HTTP request, minimal payload (7 columns),
    /// all other columns untouched. Each item must carry valid HLC values.
    ///
    /// Echo protection: callers must ensure items are `.pendingDelete` in SwiftData.
    /// Realtime echos with tombstone=true route through `applyRemoteTombstone()` which
    /// purges `.pendingDelete` items unconditionally — correct behavior.
    func bulkDeleteItems(_ items: [ItemModel], listId: UUID) async throws {
        guard !items.isEmpty else { return }

        logVoid(params: (action: "bulkDeleteItems.start", itemCount: items.count, listId: listId))

        let now = PaginationCursor.postgrestFormatter.string(from: Date())
        let payloads: [BulkTombstonePayload] = items.compactMap { item in
            guard let listUUID = UUID(uuidString: item.listId ?? ""),
                  let ts       = item.hlcTimestamp,
                  let counter  = item.hlcCounter,
                  let nodeId   = item.hlcNodeId,
                  let modifier = item.lastModifiedBy
            else {
                logVoid(params: (
                    action: "bulkDeleteItems.payloadSkipped",
                    itemId: item.id,
                    reason: "missingHLCOrListId"
                ))
                return nil
            }
            return BulkTombstonePayload(
                id: UUID(uuidString: item.id) ?? UUID(),
                listId: listUUID,
                hlcTimestamp: ts,
                hlcCounter: counter,
                hlcNodeId: nodeId,
                lastModifiedBy: modifier,
                updatedAt: now
            )
        }

        guard !payloads.isEmpty else {
            logVoid(params: (action: "bulkDeleteItems.aborted", reason: "allPayloadsSkipped"))
            return
        }

        _ = try await client
            .from("items")
            .upsert(payloads, onConflict: "id")
            .execute()

        logVoid(params: (action: "bulkDeleteItems.completed", itemCount: payloads.count, listId: listId))
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
