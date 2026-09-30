/*
 ItemCatalogRepository.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 26.09.2026

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
 - Zähler use_count/last_used_at und noteUse für „Oft gekauft“ (Migration 022, 26.09.2026).
 - imageUrl: Bildadresse aus dem globalen Katalog (Migration 035, 30.09.2026).
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
    /// Lokale Kopie des Fotos (Base64) – offline verfügbar; geht nicht mehr in die Datenbank.
    var imageData: String?
    /// EAN/UPC-Code, wenn der Artikel per Barcode-Scanner angelegt wurde (Migration 008).
    var barcode: String? = nil
    /// Storage-Pfad im Bucket `catalog-images` („<user_id>/<sha256>.jpg“, Migration 016).
    var imagePath: String? = nil
    /// Wie oft der Artikel zu einer Liste hinzugefügt wurde (Migration 022). nil = Stand ohne Zähler.
    /// Nur lesen: Gezählt wird ausschließlich über `noteUse` (RPC catalog_note_use).
    var useCount: Int? = nil
    /// Zeitpunkt der letzten Hinzufügung (Migration 022).
    var lastUsedAt: Date? = nil
    /// Bildadresse aus dem globalen Katalog (OpenFoodFacts, Migration 035). Die App lädt das Bild davon nach,
    /// wenn der Eintrag kein eigenes Foto hat. Wird nur gesendet, wenn gesetzt (Speichern ohne Adresse löscht nicht).
    var imageUrl: String? = nil

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
        case barcode
        case imagePath = "image_path"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case imageUrl = "image_url"
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

    /// Artikel verwalten: Eintrag als ItemModel mit gleicher ID bearbeiten (EditItemSheet).
    func toEditableItem() -> ItemModel {
        ItemModel(id: id, imageData: imageData, name: name, units: 1, measure: measure, price: price,
                  category: category, productDescription: productDescription, brand: brand)
    }

    /// Übernimmt die bearbeiteten Felder zurück in den Eintrag (ID, Besitzer und Barcode bleiben).
    func applying(_ item: ItemModel) -> ItemCatalogEntry {
        var copy = self
        copy.name = item.name
        copy.brand = item.brand
        copy.category = item.category
        copy.productDescription = item.productDescription
        copy.measure = item.measure
        copy.price = item.price
        copy.imageData = item.imageData
        return copy
    }

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

    /// Alle Einträge des Artikelstamms (Artikel verwalten), alphabetisch.
    func fetchAll() async throws -> [ItemCatalogEntry]

    /// Ändert einen bestehenden Eintrag über seine ID (auch der Name darf sich ändern).
    func update(_ entry: ItemCatalogEntry) async throws

    /// Löscht einen Eintrag endgültig (Artikel verwalten → Wischen).
    func delete(id: String) async throws

    /// Sucht einen eigenen Artikel mit diesem Barcode (Barcode-Scanner).
    func find(barcode: String) async throws -> ItemCatalogEntry?

    /// Lädt ein Foto des Artikelstamms aus Storage (nil = nicht unterstützt, z. B. Vorschau).
    func downloadImage(path: String) async throws -> Data?

    /// Zählt Hinzufügungen zu einer Liste („Oft gekauft“, Migration 022). Namen ohne Eintrag im
    /// eigenen Artikelstamm werden ignoriert. `date` = Zeitpunkt der Hinzufügung auf dem Gerät.
    func noteUse(names: [String], at date: Date) async throws
}

extension ItemCatalogRepository {
    // Standard-Implementierungen, damit Test-Doubles nur das Nötige überschreiben müssen.
    func fetchAll() async throws -> [ItemCatalogEntry] { [] }
    func update(_ entry: ItemCatalogEntry) async throws { try await save(entry) }
    func delete(id: String) async throws {}
    func find(barcode: String) async throws -> ItemCatalogEntry? { nil }
    func downloadImage(path: String) async throws -> Data? { nil }
    func noteUse(names: [String], at date: Date) async throws {}
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

    func fetchAll() async throws -> [ItemCatalogEntry] {
        entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func update(_ entry: ItemCatalogEntry) async throws {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) { entries[idx] = entry }
    }

    func delete(id: String) async throws {
        entries.removeAll { $0.id == id }
    }

    func find(barcode: String) async throws -> ItemCatalogEntry? {
        entries.first { $0.barcode == barcode }
    }
}
