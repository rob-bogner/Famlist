/*
 SupabaseItemsRepository+CRUD.swift
 Famlist
 Created on: 15.03.2026
 Last updated on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einziger Schreibweg für Artikel: RPC upsert_items_lww (Migration 015).

 🔰 Notes for Beginners:
 - Jeder Auftrag trägt den vollen Artikelstand samt HLC und Löschmarkierung. Der Server übernimmt ihn
   nur, wenn er neuer ist, und antwortet je Artikel mit applied/stale/denied/invalid plus gültiger Zeile.
 - Das Foto geht nur als Storage-Pfad (`image_path`) mit, und nur, wenn es sich geändert hat
   (`includeImage`). Fehlt der Schlüssel, behält der Server sein Foto. Base64 wird nicht mehr gesendet.
 - Aufträge werden in Stapeln zu höchstens 200 gesendet (Server-Grenze).

 📝 Last Change:
 - createItem/updateItem/batchUpdateItems/deleteItem durch upsertItems ersetzt (Audit 25.09.2026).
   Vorher wurde blind überschrieben: Die zuletzt ankommende Änderung gewann, nicht die neueste.
 ------------------------------------------------------------------------
*/

import Foundation
import Supabase

// MARK: - RPC Payloads

/// Ein Artikel im Format, das upsert_items_lww erwartet (Spaltennamen der Tabelle items).
private struct UpsertRow: Encodable {
    let item: ItemModel
    let includeImage: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case ownerPublicId = "ownerpublicid"
        case imagePath = "image_path"
        case name, units, measure, price, isChecked, category, brand, tombstone
        case isUnavailable = "is_unavailable"
        case productDescription = "productdescription"
        case hlcTimestamp = "hlc_timestamp"
        case hlcCounter = "hlc_counter"
        case hlcNodeId = "hlc_node_id"
        case lastModifiedBy = "last_modified_by"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(item.id, forKey: .id)
        try c.encode(item.listId, forKey: .listId)
        try c.encodeIfPresent(item.ownerPublicId, forKey: .ownerPublicId)
        // Foto nur als Storage-Pfad (Migration 016); explizites null = Foto entfernt, Schlüssel fehlt = unverändert.
        if includeImage { try c.encode(item.imagePath, forKey: .imagePath) }
        try c.encode(item.name, forKey: .name)
        try c.encode(item.units, forKey: .units)
        try c.encode(MeasureCanonicalizer.canonicalize(item.measure), forKey: .measure)
        try c.encode(item.price, forKey: .price)
        try c.encode(item.isChecked, forKey: .isChecked)
        try c.encode(item.isUnavailable, forKey: .isUnavailable)
        try c.encode(item.category, forKey: .category)
        try c.encode(item.productDescription, forKey: .productDescription)
        try c.encode(item.brand, forKey: .brand)
        try c.encode(item.tombstone ?? false, forKey: .tombstone)
        try c.encode(item.hlcTimestamp ?? 0, forKey: .hlcTimestamp)
        try c.encode(item.hlcCounter ?? 0, forKey: .hlcCounter)
        try c.encode(item.hlcNodeId ?? "", forKey: .hlcNodeId)
        try c.encodeIfPresent(item.lastModifiedBy, forKey: .lastModifiedBy)
    }
}

private struct UpsertParams: Encodable, Sendable {
    let p_items: [UpsertRow]
}

// ItemModel ist ein reiner Werttyp (Sendable) – kein @unchecked nötig.
extension UpsertRow: Sendable {}

/// Eine Zeile der RPC-Antwort.
private struct UpsertResponseRow: Decodable {
    let id: UUID?
    let status: String
    let item: AnyJSON?
}

// MARK: - Write Extension

extension SupabaseItemsRepository {

    /// Server-Grenze der RPC upsert_items_lww.
    static let upsertBatchLimit = 200

    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] {
        guard !requests.isEmpty else { return [] }
        var results: [ItemUpsertResult] = []
        var start = 0
        while start < requests.count {
            let chunk = Array(requests[start..<min(start + Self.upsertBatchLimit, requests.count)])
            let params = UpsertParams(p_items: chunk.map { UpsertRow(item: $0.item, includeImage: $0.includeImage) })
            let rows: [UpsertResponseRow] = try await client.rpcRows("upsert_items_lww", params: params)
            results += rows.map(Self.result(from:))
            start += Self.upsertBatchLimit
        }
        logVoid(params: (action: "upsertItems", count: requests.count,
                         applied: results.filter { $0.status == .applied }.count,
                         stale: results.filter { $0.status == .stale }.count,
                         rejected: results.filter { $0.status == .denied || $0.status == .invalid }.count))
        return results
    }

    private static func result(from row: UpsertResponseRow) -> ItemUpsertResult {
        let status = ItemUpsertResult.Status(rawValue: row.status) ?? .invalid
        var model: ItemModel?
        var message: String?
        if let json = row.item, let object = json.objectValue {
            if status == .invalid {
                message = object["error"]?.stringValue
            } else if let data = try? JSONEncoder().encode(json),
                      let decoded = try? JSONDecoder().decode(SupabaseItemRow.self, from: data) {
                model = decoded.toItemModel()
            }
        }
        return ItemUpsertResult(id: row.id?.uuidString ?? "", status: status, item: model, message: message)
    }
}
