/*
 GlobalProductCatalogRepository.swift

 Famlist
 Created on: 14.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Protocol and model for the global OpenFoodFacts product catalog (DACH subset).
 - Read-only; no user ownership. All authenticated users can search this table.

 🛠 Includes:
 - GlobalProductEntry model (Codable, Identifiable) mirroring global_product_catalog table.
 - GlobalProductCatalogRepository protocol with a single search operation.
 - PreviewGlobalProductCatalogRepository for SwiftUI previews with real DACH products.

 🔰 Notes for Beginners:
 - CodingKeys maps `id` to `"code"` because Supabase decodes by column name.
 - toItemCatalogEntry() produces a stub entry; the real ownerPublicId is injected
   later by ListViewModel.addItem() from the active auth session.

 📝 Last Change:
 - Initial creation for OpenFoodFacts integration.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and Codable support.

// MARK: - Model

/// A single product entry from the global OpenFoodFacts DACH catalog.
/// Maps directly to Supabase `global_product_catalog` columns via CodingKeys.
struct GlobalProductEntry: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// The product barcode (EAN/UPC). Used as the primary key in the DB.
    var id: String
    var name: String
    var brand: String?
    var category: String?
    var measure: String?
    var imageUrl: String?
    var scansN: Int

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id = "code"
        case name
        case brand
        case category
        case measure
        case imageUrl = "image_url"
        case scansN = "scans_n"
    }

    // MARK: - Conversion

    /// Creates a stub ItemCatalogEntry from this global product.
    /// - Parameter ownerPublicId: Placeholder – the real ID is filled in by ListViewModel.addItem().
    /// - Returns: An ItemCatalogEntry with `price == 0.0` and `imageData == nil`.
    func toItemCatalogEntry(ownerPublicId: String) -> ItemCatalogEntry {
        ItemCatalogEntry(
            id: UUID().uuidString,
            ownerPublicId: ownerPublicId,
            name: name,
            brand: brand,
            category: category,
            productDescription: nil,
            measure: measure ?? "",
            price: 0.0,
            imageData: nil
        )
    }
}

// MARK: - Protocol

/// Read-only contract for searching the global OpenFoodFacts product catalog.
/// Results are ordered by popularity (scans_n desc), then name alphabetically.
@MainActor
protocol GlobalProductCatalogRepository {
    /// Searches the global catalog for products whose names contain the query.
    /// Returns at most 5 results. Safe to call while offline – callers should handle errors gracefully.
    func search(query: String) async throws -> [GlobalProductEntry]
}

// MARK: - Preview / In-Memory Implementation

/// In-memory implementation with real DACH products for SwiftUI previews.
@MainActor
final class PreviewGlobalProductCatalogRepository: GlobalProductCatalogRepository {

    private let entries: [GlobalProductEntry] = [
        GlobalProductEntry(
            id: "3017620422003",
            name: "Nutella",
            brand: "Ferrero",
            category: "Aufstriche",
            measure: "400 g",
            imageUrl: "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_de.3.400.jpg",
            scansN: 250_000
        ),
        GlobalProductEntry(
            id: "4008400401690",
            name: "Haribo Goldbären",
            brand: "Haribo",
            category: "Süßigkeiten",
            measure: "200 g",
            imageUrl: "https://images.openfoodfacts.org/images/products/400/840/040/1690/front_de.4.400.jpg",
            scansN: 180_000
        ),
        GlobalProductEntry(
            id: "4388860002610",
            name: "Alpenmilch Vollmilch",
            brand: "Berchtesgadener Land",
            category: "Milch",
            measure: "1 l",
            imageUrl: nil,
            scansN: 95_000
        ),
        GlobalProductEntry(
            id: "4006040038704",
            name: "Ritter Sport Alpenmilch",
            brand: "Ritter Sport",
            category: "Schokolade",
            measure: "100 g",
            imageUrl: "https://images.openfoodfacts.org/images/products/400/604/003/8704/front_de.2.400.jpg",
            scansN: 140_000
        ),
        GlobalProductEntry(
            id: "4001533014406",
            name: "Manner Schnitten",
            brand: "Manner",
            category: "Gebäck",
            measure: "75 g",
            imageUrl: nil,
            scansN: 60_000
        )
    ]

    func search(query: String) async throws -> [GlobalProductEntry] {
        let q = query.lowercased()
        return Array(
            entries
                .filter { $0.name.lowercased().contains(q) }
                .sorted { $0.scansN > $1.scansN }
                .prefix(5)
        )
    }
}
