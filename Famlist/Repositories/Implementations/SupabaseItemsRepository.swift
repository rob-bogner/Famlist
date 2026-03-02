/*
 SupabaseItemsRepository.swift
 Famlist
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
    
    /// Tracks when the last bulk operation started for stale lock detection.
    @MainActor private var lastBulkOperationStartTime: Date?
    
    /// Maximum allowed duration for a bulk operation before considering the lock stale (14 days = 336 hours).
    /// After this duration, the lock will be automatically cleared on the next event processing.
    private let staleLockThreshold: TimeInterval = 336 * 60 * 60 // 336 hours
    
    /// Event counter for batch operations: tracks how many realtime events we're expecting.
    @MainActor private var expectedRealtimeEvents: Int = 0
    
    /// Timeout duration for event counter (fallback if not all events arrive).
    private let eventCounterTimeout: TimeInterval = 5.0 // 5 seconds
    
    // MARK: - Lifecycle
    
    init(client: SupabaseClienting, itemStore: SwiftDataItemStore, conflictResolver: ConflictResolver) {
        self.client = client
        self.realtimeManager = SupabaseRealtimeManager(client: client)
        self.eventProcessor = RealtimeEventProcessor(conflictResolver: conflictResolver, itemStore: itemStore)
    }
    
    // MARK: - Stale Lock Protection
    
    /// Checks if the suppression lock is stale (older than staleLockThreshold) and clears it if necessary.
    /// - Returns: True if a stale lock was cleared, false otherwise.
    @MainActor
    private func checkAndClearStaleLock() -> Bool {
        guard suppressRealtimeFetches,
              let startTime = lastBulkOperationStartTime else {
            return false
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > staleLockThreshold {
            suppressRealtimeFetches = false
            lastBulkOperationStartTime = nil
            expectedRealtimeEvents = 0
            logVoid(params: (
                action: "staleLockCleared",
                reason: "Lock older than \(staleLockThreshold)s (elapsed: \(elapsed)s)"
            ))
            return true
        }
        return false
    }
    
    // MARK: - Event Counter Management
    
    /// Decrements the expected realtime events counter and releases lock if all events arrived.
    /// - Parameter listId: The list ID for logging purposes.
    @MainActor
    private func decrementEventCounter(for listId: UUID) {
        guard suppressRealtimeFetches, expectedRealtimeEvents > 0 else { return }
        
        expectedRealtimeEvents -= 1
        logVoid(params: (
            action: "eventCounter.decrement",
            remaining: expectedRealtimeEvents,
            listId: listId
        ))
        
        // Release lock if all events have arrived
        if expectedRealtimeEvents == 0 {
            suppressRealtimeFetches = false
            lastBulkOperationStartTime = nil
            logVoid(params: (
                action: "eventCounter.lockReleased",
                reason: "All realtime events received",
                listId: listId
            ))
        }
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
            
            // onTermination wird vom AsyncStream-System ohne garantierten Thread aufgerufen.
            // Task { @MainActor in ... } stellt sicher, dass continuations nur auf dem Main Actor mutiert wird.
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.continuations[listId]?.removeValue(forKey: token)
                    // If no more observers for this list, remove the Realtime channel
                    if self.continuations[listId]?.isEmpty == true {
                        self.realtimeManager.teardownRealtimeChannel(for: listId)
                        self.continuations.removeValue(forKey: listId)
                    }
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
        // Check for stale locks first (crash recovery)
        let staleCleared = await MainActor.run { checkAndClearStaleLock() }
        if staleCleared {
            logVoid(params: (action: "processRealtimeEvent.staleLockRecovered", listId: listId))
        }
        
        // EVENT COUNTER: Decrement counter for batch-triggered updates
        let isWaitingForBatchEvents = await MainActor.run { suppressRealtimeFetches && expectedRealtimeEvents > 0 }
        if isWaitingForBatchEvents {
            // Only decrement for UPDATE events (our batch operation only does updates)
            if case .update = event {
                await MainActor.run { decrementEventCounter(for: listId) }
            }
            
            // Skip processing - we'll do a final fetch once all events arrive or timeout
            logVoid(params: (
                action: "processRealtimeEvent.skipped",
                reason: "waitingForBatchEvents",
                listId: listId
            ))
            return
        }
        
        // PESSIMISTIC LOCKING: Ignore ALL Realtime events during bulk operations (without event counter).
        // Rationale: Final fetch after bulk operation will sync state correctly.
        // This prevents cascading fetches and ensures atomicity of bulk updates.
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
            // Note: User-Log für itemsLoaded wurde entfernt, da fetchAndYield bei jedem Realtime-Event aufgerufen wird.
            // User-Logs erfolgen spezifisch für die jeweiligen Operationen (add, update, delete, realtime-events).
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
        let result = logResult(params: (itemId: model.id, listId: listUUID), result: model)
        UserLog.Data.itemAdded(name: item.name, units: item.units, measure: item.measure)
        return result
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
        UserLog.Data.itemUpdated(name: item.name, units: item.units, measure: item.measure)
    }
    
    /// Batch-update multiple items in parallel using event counter strategy.
    ///
    /// **Strategy:**
    /// 1. Acquire lock (`suppressRealtimeFetches = true`) and set event counter to number of items
    /// 2. Execute all updates in parallel using TaskGroup
    /// 3. Wait for all realtime events to arrive (counter reaches 0) OR timeout (5s)
    /// 4. Release lock and perform final fetch to synchronize with database state
    ///
    /// **Rationale:**
    /// - Event counter ensures we wait for all Realtime events without fixed delay
    /// - Timeout provides fallback if some events are lost/delayed
    /// - Final fetch ensures consistency regardless of which path triggered release
    /// - No arbitrary delays → robust and responsive
    ///
    /// - Parameters:
    ///   - items: Array of ItemModels to update
    ///   - listId: The list that the items belong to
    /// - Throws: Database errors if any update fails
    func batchUpdateItems(_ items: [ItemModel], listId: UUID) async throws {
        guard !items.isEmpty else { return }
        
        logVoid(params: (
            action: "batchUpdateItems.start",
            itemCount: items.count,
            listId: listId
        ))
        UserLog.Data.bulkUpdate(count: items.count)
        
        // Acquire lock: Suppress realtime fetches during batch and set event counter
        await MainActor.run {
            self.suppressRealtimeFetches = true
            self.expectedRealtimeEvents = items.count
            self.lastBulkOperationStartTime = Date()
            logVoid(params: (
                action: "batchUpdateItems.suppressionEnabled",
                expectedEvents: items.count,
                listId: listId
            ))
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
            
            // Start timeout task that will release lock after eventCounterTimeout if events don't arrive
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(eventCounterTimeout * 1_000_000_000))
                await MainActor.run {
                    // Only release if still suppressing (event counter might have already released it)
                    if self.suppressRealtimeFetches {
                        let remainingEvents = self.expectedRealtimeEvents
                        self.suppressRealtimeFetches = false
                        self.expectedRealtimeEvents = 0
                        self.lastBulkOperationStartTime = nil
                        logVoid(params: (
                            action: "batchUpdateItems.suppressionDisabled.timeout",
                            reason: "Timeout reached with \(remainingEvents) events still pending",
                            listId: listId
                        ))
                    }
                }
            }
            
            // Wait for either all events to arrive OR timeout
            let startTime = Date()
            while await MainActor.run(body: { self.suppressRealtimeFetches }) {
                try? await Task.sleep(nanoseconds: 50_000_000) // Check every 50ms
                
                // Safety check: break if timeout already passed
                if Date().timeIntervalSince(startTime) > eventCounterTimeout + 0.5 {
                    break
                }
            }
            
            // Cancel timeout task if events arrived before timeout
            timeoutTask.cancel()
            
            // Ensure lock is released (might already be released by event counter or timeout)
            await MainActor.run {
                if self.suppressRealtimeFetches {
                    self.suppressRealtimeFetches = false
                    self.expectedRealtimeEvents = 0
                    self.lastBulkOperationStartTime = nil
                    logVoid(params: (action: "batchUpdateItems.suppressionDisabled.manual", listId: listId))
                }
            }
            
            // Final fetch synchronizes state with database (includes any changes from other clients)
            await fetchAndYield(listId)
        } catch {
            // Release lock on error: Re-enable realtime fetches and clear all state
            await MainActor.run {
                self.suppressRealtimeFetches = false
                self.expectedRealtimeEvents = 0
                self.lastBulkOperationStartTime = nil
                logVoid(params: (action: "batchUpdateItems.suppressionDisabled.error", listId: listId, error: error.localizedDescription))
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
        UserLog.Data.itemDeleted()
    }
}
