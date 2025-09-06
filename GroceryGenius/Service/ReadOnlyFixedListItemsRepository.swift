/*
 ReadOnlyFixedListItemsRepository.swift

 GroceryGenius
 Created on: 06.09.2025
 Last updated on: 06.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Read-only ItemsRepository that fetches items for a single, hard-coded list id and exposes them via a one-shot AsyncStream.

 🛠 Includes:
 - ReadOnlyFixedListItemsRepository conforming to ItemsRepository.
 - Minimal row mapping to convert DB columns into ItemModel.

 🔰 Notes for Beginners:
 - This repository ignores create/update/delete and will throw if they are called.
 - observeItems(listId:) ignores the input listId and always queries the fixed list.

 📝 Last Change:
 - Initial creation per request to “just read items with a fixed list id.”
 ------------------------------------------------------------------------
 */

import Foundation // Provides UUID and Codable for mapping.

/// Errors specific to the read-only repository.
enum ReadOnlyRepoError: Error { case readOnly } // Thrown when a write API is invoked.

/// Read-only repository that fetches items for a single, hard-coded list id.
final class ReadOnlyFixedListItemsRepository: ItemsRepository { // Conforms to ItemsRepository for easy wiring.
    private let client: SupabaseClienting // Underlying Supabase client wrapper.
    private let fixedListId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")! // Required fixed list id.

    /// Create with a Supabase client abstraction.
    init(client: SupabaseClienting) { self.client = client } // Store dependency.

    /// One-shot stream: fetches items for the fixed list and yields once, then finishes.
    func observeItems(listId _: UUID) -> AsyncStream<[ItemModel]> { // Ignore input listId.
        AsyncStream { continuation in // Build a stream with manual yields.
            Task { // Perform async fetch.
                do {
                    let rows: [Row] = try await client
                        .from("items")
                        .select()
                        .eq("list_id", value: fixedListId.uuidString)
                        .order("position", ascending: true)
                        .order("created_at", ascending: true)
                        .execute()
                        .value // Decode into Row array.
                    let mapped = rows.map(map) // Convert to ItemModel.
                    continuation.yield(mapped) // Emit once.
                } catch {
                    continuation.yield([]) // On failure, emit empty list.
                }
                continuation.finish() // Complete stream.
            }
        }
    }

    /// Not supported in read-only mode.
    func createItem(_ item: ItemModel) async throws -> ItemModel { throw ReadOnlyRepoError.readOnly }

    /// Not supported in read-only mode.
    func updateItem(_ item: ItemModel) async throws { throw ReadOnlyRepoError.readOnly }

    /// Not supported in read-only mode.
    func deleteItem(id: String, listId: UUID) async throws { throw ReadOnlyRepoError.readOnly }

    // MARK: - Mapping
    /// Minimal row mapping from the DB to Swift.
    private struct Row: Codable { // Mirrors items table columns used by the UI.
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
        let position: Int?
        let createdAt: String?
        let updatedAt: String?
        enum CodingKeys: String, CodingKey {
            case id
            case listId = "list_id"
            case ownerPublicId = "ownerpublicid"
            case imageData = "imagedata"
            case name, units, measure, price, isChecked, category
            case productDescription = "productdescription"
            case brand, position
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
    /// Maps a Row into the app-level ItemModel.
    private func map(_ r: Row) -> ItemModel {
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
            ownerPublicId: r.ownerPublicId
        )
    }
}
