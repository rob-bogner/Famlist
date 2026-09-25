/*
 SupabaseItemRow.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeile der Tabelle items im PostgREST-Format (auch in der Antwort von upsert_items_lww) samt Umwandlung in ItemModel.

 📝 Last Change:
 - Aus SupabaseItemsRepository.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

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
