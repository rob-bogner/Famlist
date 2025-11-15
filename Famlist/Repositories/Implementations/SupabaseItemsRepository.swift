/*
 SupabaseItemsRepository.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Supabase-backed implementation of ItemsRepository with Realtime support.
 🛠 Includes: Item CRUD operations, Realtime channel management, and live updates.
 🔰 Notes for Beginners: Isolates Supabase-specific logic from UI/ViewModels.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.
import Supabase // Brings in Supabase types for queries and builders.

/// Supabase-backed items repository implementing ItemsRepository.
final class SupabaseItemsRepository: ItemsRepository {
    let client: SupabaseClienting // Facade client used for DB calls.
    
    // Track continuations with tokens (Continuation is a struct)
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]
    
    // Track Realtime channels for each list to enable cleanup on unsubscribe
    private var channels: [UUID: RealtimeChannelV2] = [:]

    init(client: SupabaseClienting) {
        self.client = client
    }

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        let stream = AsyncStream { continuation in
            let token = UUID()
            if continuations[listId] == nil {
                continuations[listId] = [:]
            }
            continuations[listId]?[token] = continuation
            
            // Set up Realtime subscription if this is the first observer for this list
            if self.continuations[listId]?.count == 1, self.channels[listId] == nil {
                Task { await self.setupRealtimeChannel(for: listId) }
            }
            
            continuation.onTermination = { _ in
                self.continuations[listId]?.removeValue(forKey: token)
                // If no more observers for this list, remove the Realtime channel
                if self.continuations[listId]?.isEmpty == true {
                    self.teardownRealtimeChannel(for: listId)
                    self.continuations.removeValue(forKey: listId)
                }
            }
            Task { await self.fetchAndYield(listId) }
        }
        return logResult(params: ["listId": listId], result: stream)
    }
    
    /// Sets up a Realtime channel to listen for changes on the items table for a specific list.
    /// Following the pattern from: https://ardyan.medium.com/building-chat-app-with-supabase-swiftui-in-under-100-lines-of-code-d01285f6e87a
    private func setupRealtimeChannel(for listId: UUID) async {
        let channelId = "public:items:\(listId)"
        logVoid(params: (listId: listId, action: "setupChannel", channelId: channelId))
        
        let channel = client.realtime.channel(channelId)
        
        // Create AsyncStreams for each change type using postgresChange with type-safe filter syntax
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "items",
            filter: .eq("list_id", value: listId.uuidString)
        )
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "items",
            filter: .eq("list_id", value: listId.uuidString)
        )
        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "items",
            filter: .eq("list_id", value: listId.uuidString)
        )
        
        // Subscribe to the channel BEFORE consuming the streams
        do {
            try await channel.subscribeWithError()
            logVoid(params: (listId: listId, action: "channelSubscribed", channelId: channelId, status: "success"))
        } catch {
            logVoid(params: (listId: listId, action: "channelSubscribed", channelId: channelId, status: "failed", error: String(describing: error)))
            return
        }
        
        // Store channel for later cleanup
        channels[listId] = channel
        
        // Process insertions in background task
        Task {
            for await insertion in insertions {
                logVoid(params: (listId: listId, action: "realtimeInsert", record: insertion.record))
                await fetchAndYield(listId)
            }
        }
        
        // Process updates in background task
        Task {
            for await update in updates {
                logVoid(params: (listId: listId, action: "realtimeUpdate", record: update.record))
                await fetchAndYield(listId)
            }
        }
        
        // Process deletions in background task
        Task {
            for await deletion in deletions {
                logVoid(params: (listId: listId, action: "realtimeDelete", oldRecord: deletion.oldRecord))
                await fetchAndYield(listId)
            }
        }
    }
    
    /// Tears down the Realtime channel for a specific list when no more observers exist.
    private func teardownRealtimeChannel(for listId: UUID) {
        guard let channel = channels[listId] else { return }
        Task { await channel.unsubscribe() }
        channels.removeValue(forKey: listId)
        logVoid(params: (listId: listId, action: "teardownRealtimeChannel"))
    }

    @MainActor
    private func yield(_ listId: UUID, _ items: [ItemModel]) {
        continuations[listId]?.values.forEach { $0.yield(items) }
    }

    private func fetchAndYield(_ listId: UUID) async {
        struct Row: Codable {
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
            let createdAt: String?
            let updatedAt: String?
            enum CodingKeys: String, CodingKey {
                case id
                case listId = "list_id"
                case ownerPublicId = "ownerpublicid"
                case imageData = "imagedata"
                case name, units, measure, price, isChecked, category
                case productDescription = "productdescription"
                case brand
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        do {
            let rows: [Row] = try await client
                .from("items")
                .select()
                .eq("list_id", value: listId.uuidString)
                .order("created_at", ascending: true) // Sort by creation time to keep stable order
                .execute()
                .value
            let mapped = rows.map { r in
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
            await MainActor.run { self.yield(listId, mapped) }
            logVoid(params: (listId: listId, itemsCount: mapped.count))
        } catch {
            logVoid(params: (listId: listId, note: "fetchError", error: String(describing: error)))
        }
    }

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        // Technical Debt: Still using Base64 imageData instead of Storage URLs
        let finalImageData: String? = item.imageData
        struct NewRow: Codable {
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
            enum CodingKeys: String, CodingKey {
                case id
                case listId = "list_id"
                case ownerPublicId = "ownerpublicid"
                case imageData = "imagedata"
                case name, units, measure, price, isChecked, category
                case productDescription = "productdescription"
                case brand
            }
        }
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
        let row = NewRow(
            id: UUID(uuidString: item.id) ?? UUID(),
            listId: listUUID,
            ownerPublicId: item.ownerPublicId,
            imageData: finalImageData,
            name: item.name,
            units: item.units,
            measure: item.measure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand
        )
        _ = try await client.from("items").insert(row).execute()
        await fetchAndYield(listUUID)
        let model = ItemModel(
            id: row.id.uuidString,
            imageUrl: item.imageUrl,
            imageData: finalImageData,
            name: item.name,
            units: item.units,
            measure: item.measure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand,
            listId: listUUID.uuidString,
            ownerPublicId: item.ownerPublicId
        )
        return logResult(params: (itemId: model.id, listId: listUUID), result: model)
    }

    func updateItem(_ item: ItemModel) async throws {
        guard let listIdString = item.listId else {
            throw NSError(domain: "SupabaseItemsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Item update requires valid listId"])
        }
        let finalImageData: String? = item.imageData
        let listId = UUID(uuidString: listIdString) ?? UUID()
        
        // Custom encodable struct that explicitly encodes nil values as JSON null
        // This ensures Supabase actually clears the fields instead of skipping them
        struct UpdateRow: Encodable {
            let imageData: String?
            let name: String
            let units: Int
            let measure: String
            let price: Double
            let isChecked: Bool
            let category: String?
            let productDescription: String?
            let brand: String?
            
            enum CodingKeys: String, CodingKey {
                case imageData = "imagedata"
                case name, units, measure, price, isChecked, category
                case productDescription = "productdescription"
                case brand
            }
            
            // Custom encoder that explicitly encodes nil values as null
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(imageData, forKey: .imageData)
                try container.encode(name, forKey: .name)
                try container.encode(units, forKey: .units)
                try container.encode(measure, forKey: .measure)
                try container.encode(price, forKey: .price)
                try container.encode(isChecked, forKey: .isChecked)
                try container.encode(category, forKey: .category)
                try container.encode(productDescription, forKey: .productDescription)
                try container.encode(brand, forKey: .brand)
            }
        }
        
        let payload = UpdateRow(
            imageData: finalImageData,
            name: item.name,
            units: item.units,
            measure: item.measure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand
        )
        
        _ = try await client
            .from("items")
            .update(payload)
            .eq("id", value: item.id)
            .eq("list_id", value: listIdString)
            .execute()
        await fetchAndYield(listId)
        logVoid(params: (itemId: item.id, listId: listId))
    }

    func deleteItem(id: String, listId: UUID) async throws {
        _ = try await client
            .from("items")
            .delete()
            .eq("id", value: id)
            .eq("list_id", value: listId.uuidString)
            .execute()
        await fetchAndYield(listId)
        logVoid(params: (id: id, listId: listId))
    }
}

