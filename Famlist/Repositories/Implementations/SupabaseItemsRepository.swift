/*
 SupabaseItemsRepository.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Supabase-backed implementation of ItemsRepository with Realtime support.
 🛠 Includes: Item CRUD operations and live updates orchestration.
 🔰 Notes for Beginners: Isolates Supabase-specific logic from UI/ViewModels.
 📝 Last Change: Refactored to delegate Realtime channel management to SupabaseRealtimeManager.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.
import Supabase // Brings in Supabase types for queries and builders.

/// Supabase-backed items repository implementing ItemsRepository.
final class SupabaseItemsRepository: ItemsRepository {
    
    // MARK: - Dependencies
    
    let client: SupabaseClienting
    private let realtimeManager: SupabaseRealtimeManager
    private let eventProcessor: RealtimeEventProcessor
    
    // MARK: - State
    
    /// Track continuations with tokens for each list.
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]
    
    /// Suppress realtime-triggered fetches during batch operations to avoid cascade
    /// Thread-safe durch Nutzung eines Actors wäre ideal, aber für Einfachheit nutzen wir @MainActor
    @MainActor
    private var suppressRealtimeFetches: Bool = false
    
    // MARK: - Lifecycle
    
    init(client: SupabaseClienting, itemStore: SwiftDataItemStore, conflictResolver: ConflictResolver) {
        self.client = client
        self.realtimeManager = SupabaseRealtimeManager(client: client)
        self.eventProcessor = RealtimeEventProcessor(conflictResolver: conflictResolver, itemStore: itemStore)
    }
    
    // MARK: - Observation
    
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        let stream = AsyncStream { continuation in
            let token = UUID()
            if continuations[listId] == nil {
                continuations[listId] = [:]
            }
            continuations[listId]?[token] = continuation
            
            // Set up Realtime subscription if this is the first observer for this list
            if self.continuations[listId]?.count == 1 {
                Task {
                    await self.realtimeManager.setupRealtimeChannel(for: listId) { [weak self] event in
                        await self?.processRealtimeEvent(event, listId: listId)
                    }
                }
            }
            
            continuation.onTermination = { _ in
                self.continuations[listId]?.removeValue(forKey: token)
                // If no more observers for this list, remove the Realtime channel
                if self.continuations[listId]?.isEmpty == true {
                    self.realtimeManager.teardownRealtimeChannel(for: listId)
                    self.continuations.removeValue(forKey: listId)
                }
            }
            Task {
                await self.fetchAndYield(listId)
            }
        }
        return logResult(params: ["listId": listId], result: stream)
    }
    
    @MainActor
    private func yield(_ listId: UUID, _ items: [ItemModel]) {
        continuations[listId]?.values.forEach { $0.yield(items) }
    }
    
    /// Processes a Realtime event using the event processor (granular updates)
    private func processRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
        // Skip fetch during batch operations to avoid cascade of fetches
        // Check BEFORE processing to avoid unnecessary work
        let shouldSuppress = await MainActor.run { suppressRealtimeFetches }
        if shouldSuppress {
            logVoid(params: (
                action: "processRealtimeEvent.skipped",
                reason: "batchOperationInProgress",
                listId: listId
            ))
            return
        }
        
        switch event {
        case .insert(let payload):
            await eventProcessor.processInsertion(payload, listId: listId)
        case .update(let payload):
            await eventProcessor.processUpdate(payload, listId: listId)
        case .delete(let payload):
            await eventProcessor.processDeletion(payload, listId: listId)
        }
        
        // After processing event, yield updated items from store
        // Note: This still fetches, but only after event processing, not on every event
        await fetchAndYield(listId)
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
                .order("created_at", ascending: true)
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
            await MainActor.run {
                self.yield(listId, mapped)
            }
            logVoid(params: (listId: listId, itemsCount: mapped.count))
        } catch {
            logVoid(params: (
                listId: listId,
                note: "fetchError",
                error: String(describing: error)
            ))
        }
    }
    
    // MARK: - CRUD Operations
    
    func createItem(_ item: ItemModel) async throws -> ItemModel {
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
            imageData: item.imageData,
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
            imageData: item.imageData,
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
            throw NSError(
                domain: "SupabaseItemsRepository",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Item update requires valid listId"]
            )
        }
        let listId = UUID(uuidString: listIdString) ?? UUID()
        
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
            imageData: item.imageData,
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
    
    func batchUpdateItems(_ items: [ItemModel], listId: UUID) async throws {
        guard !items.isEmpty else { return }
        
        logVoid(params: (
            action: "batchUpdateItems.start",
            itemCount: items.count,
            listId: listId
        ))
        
        // Suppress realtime fetches during batch to avoid cascade
        // Set on MainActor to ensure visibility across all tasks
        await MainActor.run {
            suppressRealtimeFetches = true
            logVoid(params: (action: "batchUpdateItems.suppressionEnabled", listId: listId))
        }
        
        do {
            // Update all items in parallel using TaskGroup
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in items {
                    group.addTask {
                        guard let listIdForItem = item.listId,
                              let listUUID = UUID(uuidString: listIdForItem) else {
                            throw NSError(domain: "SupabaseItemsRepository",
                                        code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "Missing list_id"])
                        }
                        
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
                                case name, units, measure, price
                                case isChecked = "isChecked"
                                case category
                                case productDescription = "productdescription"
                                case brand
                            }
                        }
                        
                        let payload = UpdateRow(
                            imageData: item.imageData,
                            name: item.name,
                            units: item.units,
                            measure: item.measure,
                            price: item.price,
                            isChecked: item.isChecked,
                            category: item.category,
                            productDescription: item.productDescription,
                            brand: item.brand
                        )
                        
                        _ = try await self.client
                            .from("items")
                            .update(payload)
                            .eq("id", value: item.id)
                            .eq("list_id", value: listUUID.uuidString)
                            .execute()
                    }
                }
                
                // Wait for all updates to complete
                try await group.waitForAll()
            }
            
            // Delay to ensure all Realtime events triggered by our updates have arrived.
            // This prevents race conditions where Realtime events arrive after we re-enable fetches.
            // 500ms should cover network latency and Supabase Realtime event propagation delays.
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Re-enable realtime fetches before final fetch
            await MainActor.run {
                suppressRealtimeFetches = false
                logVoid(params: (action: "batchUpdateItems.suppressionDisabled", listId: listId))
            }
            
            // Only fetch once after all updates are done
            await fetchAndYield(listId)
        } catch {
            // Re-enable realtime fetches on error
            await MainActor.run {
                suppressRealtimeFetches = false
                logVoid(params: (action: "batchUpdateItems.suppressionDisabledOnError", listId: listId))
            }
            throw error
        }
        
        logVoid(params: (
            action: "batchUpdateItems.completed",
            itemCount: items.count,
            listId: listId
        ))
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
