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
 - Fotos in Storage statt Base64 (Migration 016); fetchAll seitenweise (Audit 25.09.2026).
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
    /// image_data nur noch für den Umzug alter Fotos nach Storage (Migration 016).
    private static let columns = "id,owner_public_id,name,brand,category,product_description,measure,price,image_data,image_path,barcode"
    /// Seitengröße für fetchAll (PostgREST liefert sonst höchstens `max_rows` Zeilen – ohne Hinweis).
    static let pageSize = 500

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
        catalogEntry.imagePath = try await uploadImage(of: catalogEntry, userId: session.user.id)
        try await client
            .from("item_catalog")
            .upsert(CatalogInsert(catalogEntry), onConflict: "owner_public_id,name_lower")
            .execute()
    }

    /// Foto nach catalog-images/<user>/<sha256>.jpg; liefert den Pfad (nil = kein Foto).
    private func uploadImage(of entry: ItemCatalogEntry, userId: UUID) async throws -> String? {
        guard let base64 = entry.imageData,
              let object = ProductImageCodec.storageObject(folder: userId, base64: base64) else { return nil }
        try await client.storageUpload(bucket: ProductImageCodec.catalogBucket, path: object.path,
                                       data: object.data, contentType: "image/jpeg")
        return object.path
    }

    func downloadImage(path: String) async throws -> Data? {
        try await client.storageDownload(bucket: ProductImageCodec.catalogBucket, path: path)
    }

    /// Alle Einträge des Nutzers (RLS begrenzt auf owner_public_id = auth.uid()).
    func fetchAll() async throws -> [ItemCatalogEntry] {
        var all: [ItemCatalogEntry] = []
        var offset = 0
        while true {
            let page: [ItemCatalogEntry] = try await client
                .from("item_catalog")
                .select(Self.columns)
                .order("name_lower", ascending: true)
                .order("id", ascending: true)
                .range(from: offset, to: offset + Self.pageSize - 1)
                .execute()
                .value
            all += page
            guard page.count == Self.pageSize else { return all }
            offset += Self.pageSize
        }
    }

    /// Ändert einen Eintrag über seine ID; owner_public_id bleibt unverändert (RLS).
    func update(_ entry: ItemCatalogEntry) async throws {
        let session = try await client.auth.session
        var updated = entry
        updated.imagePath = try await uploadImage(of: entry, userId: session.user.id)
        try await client
            .from("item_catalog")
            .update(CatalogUpdate(updated))
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
    let imagePath: String?

    init(_ entry: ItemCatalogEntry) {
        name = entry.name
        brand = entry.brand
        category = entry.category
        productDescription = entry.productDescription
        measure = entry.measure
        price = entry.price
        imagePath = entry.imagePath
    }

    enum CodingKeys: String, CodingKey {
        case name, brand, category, measure, price
        case productDescription = "product_description"
        case imagePath = "image_path"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(brand, forKey: .brand)                       // explizit null → Feld leeren
        try c.encode(category, forKey: .category)
        try c.encode(productDescription, forKey: .productDescription)
        try c.encode(measure, forKey: .measure)
        try c.encode(price, forKey: .price)
        try c.encode(imagePath, forKey: .imagePath)             // Trigger leert dabei das alte image_data
    }
}

/// Neuer Eintrag (Upsert) ohne Base64 – das Foto steht nur als Storage-Pfad in der Zeile.
private struct CatalogInsert: Encodable {
    let entry: ItemCatalogEntry
    init(_ entry: ItemCatalogEntry) { self.entry = entry }

    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, measure, price, barcode
        case ownerPublicId = "owner_public_id"
        case productDescription = "product_description"
        case imagePath = "image_path"
        case imageData = "image_data"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entry.id, forKey: .id)
        try c.encode(entry.ownerPublicId, forKey: .ownerPublicId)
        try c.encode(entry.name, forKey: .name)
        try c.encode(entry.brand, forKey: .brand)
        try c.encode(entry.category, forKey: .category)
        try c.encode(entry.productDescription, forKey: .productDescription)
        try c.encode(entry.measure, forKey: .measure)
        try c.encode(entry.price, forKey: .price)
        try c.encodeIfPresent(entry.barcode, forKey: .barcode)
        try c.encode(entry.imagePath, forKey: .imagePath)
        try c.encodeNil(forKey: .imageData)                        // altes Base64 beim Upsert leeren
    }
}
