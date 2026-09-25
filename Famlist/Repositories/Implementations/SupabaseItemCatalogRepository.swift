/*
 SupabaseItemCatalogRepository.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 12.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-backed implementation of ItemCatalogRepository.
 - Searches and upserts entries in the item_catalog table.

 🛠 Includes:
 - search(): ILIKE query on name_lower, returns top 5 results.
 - save(): upsert with conflict resolution on (owner_public_id, name_lower).

 🔰 Notes for Beginners:
 - RLS on the item_catalog table ensures each user only sees their own entries.
 - No explicit owner filter needed in queries; RLS handles it automatically.

 📝 Last Change:
 - Initial creation for FAM-60 smart search feature.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID.
import Supabase // Supabase client for PostgREST queries.

/// Supabase-backed item catalog repository.
/// @MainActor ensures all DB calls and state are on the main thread.
@MainActor
final class SupabaseItemCatalogRepository: ItemCatalogRepository {

    // MARK: - Dependencies

    let client: SupabaseClienting

    // MARK: - Init

    init(client: SupabaseClienting) {
        self.client = client
    }

    /// Security: nur die Spalten, die die UI braucht.
    private static let columns = "id,owner_public_id,name,brand,category,product_description,measure,price,image_data,barcode"

    // MARK: - ItemCatalogRepository

    /// Searches the item_catalog table for entries whose name_lower contains the query.
    /// RLS ensures results are scoped to the authenticated user.
    func search(query: String) async throws -> [ItemCatalogEntry] {
        // Security: restrict returned columns to only what the UI needs
        let results: [ItemCatalogEntry] = try await client
            .from("item_catalog")
            .select(Self.columns)
            .ilike("name_lower", pattern: "%\(query.lowercased())%")
            .order("name_lower", ascending: true)
            .limit(5)
            .execute()
            .value
        return results
    }

    /// Upserts a catalog entry. Existing entries with the same owner + name are updated.
    /// Always resolves owner_public_id from the active auth session to guarantee RLS compliance.
    func save(_ entry: ItemCatalogEntry) async throws {
        let session = try await client.auth.session
        var catalogEntry = entry
        // PostgreSQL uuid::text produces lowercase; Swift UUID.uuidString produces uppercase.
        // Lowercase is required for the RLS policy: owner_public_id = auth.uid()::TEXT
        catalogEntry.ownerPublicId = session.user.id.uuidString.lowercased()
        try await client
            .from("item_catalog")
            .upsert(catalogEntry, onConflict: "owner_public_id,name_lower")
            .execute()
    }

    /// Alle Einträge des Nutzers (RLS begrenzt auf owner_public_id = auth.uid()).
    func fetchAll() async throws -> [ItemCatalogEntry] {
        try await client
            .from("item_catalog")
            .select(Self.columns)
            .order("name_lower", ascending: true)
            .execute()
            .value
    }

    /// Ändert einen Eintrag über seine ID; owner_public_id bleibt unverändert (RLS).
    func update(_ entry: ItemCatalogEntry) async throws {
        try await client
            .from("item_catalog")
            .update(CatalogUpdate(entry))
            .eq("id", value: entry.id)
            .execute()
    }

    func delete(id: String) async throws {
        try await client
            .from("item_catalog")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func find(barcode: String) async throws -> ItemCatalogEntry? {
        let rows: [ItemCatalogEntry] = try await client
            .from("item_catalog")
            .select(Self.columns)
            .eq("barcode", value: barcode)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}

/// Änderbare Spalten eines Katalog-Eintrags (ohne id / owner_public_id).
private struct CatalogUpdate: Encodable {
    let name: String
    let brand: String?
    let category: String?
    let productDescription: String?
    let measure: String
    let price: Double
    let imageData: String?

    init(_ entry: ItemCatalogEntry) {
        name = entry.name
        brand = entry.brand
        category = entry.category
        productDescription = entry.productDescription
        measure = entry.measure
        price = entry.price
        imageData = entry.imageData
    }

    enum CodingKeys: String, CodingKey {
        case name, brand, category, measure, price
        case productDescription = "product_description"
        case imageData = "image_data"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(brand, forKey: .brand)                       // explizit null → Feld leeren
        try c.encode(category, forKey: .category)
        try c.encode(productDescription, forKey: .productDescription)
        try c.encode(measure, forKey: .measure)
        try c.encode(price, forKey: .price)
        try c.encode(imageData, forKey: .imageData)
    }
}
