/*
 ItemCatalogRepository.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 12.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Protocol and model for the user's personal item catalog (persönlicher Artikelkatalog).
 - The catalog stores every item a user has ever added to any list, enabling smart search.

 🛠 Includes:
 - ItemCatalogEntry model (Codable, Identifiable) mirroring item_catalog Supabase table.
 - ItemCatalogRepository protocol with search and save operations.
 - PreviewItemCatalogRepository for SwiftUI previews and offline demo.

 🔰 Notes for Beginners:
 - The catalog is user-scoped; RLS on Supabase filters by auth.uid() automatically.
 - search() returns at most 5 results, filtered by a case-insensitive name match.
 - save() uses upsert to avoid duplicates (unique on owner_public_id + name_lower).

 📝 Last Change:
 - Initial creation for FAM-60 smart search feature.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and Codable support.

// MARK: - Model

/// Represents a single entry in the user's personal item catalog (item_catalog table).
/// Maps directly to Supabase columns using CodingKeys for snake_case field names.
struct ItemCatalogEntry: Codable, Identifiable, Equatable {

    // MARK: - Properties

    var id: String
    var ownerPublicId: String
    var name: String
    var brand: String?
    var category: String?
    var productDescription: String?
    var measure: String
    var price: Double
    var imageData: String?

    // MARK: - CodingKeys (maps camelCase Swift properties to snake_case DB columns)

    enum CodingKeys: String, CodingKey {
        case id
        case ownerPublicId = "owner_public_id"
        case name
        case brand
        case category
        case productDescription = "product_description"
        case measure
        case price
        case imageData = "image_data"
    }

    // MARK: - Factory

    /// Creates a catalog entry from an ItemModel and a known owner public ID.
    static func from(item: ItemModel, ownerPublicId: String) -> ItemCatalogEntry {
        ItemCatalogEntry(
            id: UUID().uuidString,
            ownerPublicId: ownerPublicId,
            name: item.name,
            brand: item.brand,
            category: item.category,
            productDescription: item.productDescription,
            measure: item.measure,
            price: item.price,
            imageData: item.imageData
        )
    }

    // MARK: - Conversion

    /// Converts this catalog entry into a new ItemModel ready to be added to a list.
    /// - Parameters:
    ///   - listId: The target list identifier.
    ///   - ownerPublicId: The owner's public ID.
    func toItemModel(listId: String?, ownerPublicId: String?) -> ItemModel {
        ItemModel(
            id: UUID().uuidString,
            imageData: imageData,
            name: name,
            units: 1,
            measure: measure,
            price: price,
            isChecked: false,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId,
            ownerPublicId: ownerPublicId
        )
    }
}

// MARK: - Protocol

/// Contract for searching and persisting entries in the user's personal item catalog.
@MainActor
protocol ItemCatalogRepository {
    /// Searches the catalog for items whose names contain the given query (min 2 chars).
    /// Returns at most 5 results ordered alphabetically.
    func search(query: String) async throws -> [ItemCatalogEntry]

    /// Upserts a catalog entry. Entries with the same owner + lowercase name are updated, not duplicated.
    func save(_ entry: ItemCatalogEntry) async throws
}

// MARK: - Preview / In-Memory Implementation

/// Simple in-memory catalog repository for SwiftUI previews and offline demos.
@MainActor
final class PreviewItemCatalogRepository: ItemCatalogRepository {
    private var entries: [ItemCatalogEntry] = [
        ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "preview", name: "Milch", brand: "Weihenstephan", category: "Molkerei", productDescription: "Vollmilch 3,5%", measure: "l", price: 1.49, imageData: nil),
        ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "preview", name: "Brot", brand: nil, category: "Backwaren", productDescription: nil, measure: "Stück", price: 2.99, imageData: nil),
        ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "preview", name: "Butter", brand: "Kerrygold", category: "Molkerei", productDescription: nil, measure: "Packung", price: 1.89, imageData: nil),
        ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "preview", name: "Eier", brand: nil, category: "Molkerei", productDescription: "Freilandeier Gr. M", measure: "Stück", price: 3.29, imageData: nil),
        ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "preview", name: "Mehl", brand: nil, category: "Grundnahrung", productDescription: "Weizenmehl Typ 405", measure: "kg", price: 0.89, imageData: nil)
    ]

    func search(query: String) async throws -> [ItemCatalogEntry] {
        let q = query.lowercased()
        return Array(entries.filter { $0.name.lowercased().contains(q) }.prefix(5))
    }

    func save(_ entry: ItemCatalogEntry) async throws {
        if let idx = entries.firstIndex(where: { $0.name.lowercased() == entry.name.lowercased() && $0.ownerPublicId == entry.ownerPublicId }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }
}
