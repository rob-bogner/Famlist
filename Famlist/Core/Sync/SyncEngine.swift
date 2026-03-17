/*
 SyncEngine.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Central orchestrator for all sync operations between SwiftData and Supabase.
 
 🛠 Includes:
 - CRUD operations with automatic queuing
 - Exponential backoff retry logic
 - Background queue processing
 - HLC generation and CRDT metadata management
 
 🔰 Notes for Beginners:
 - This is the heart of the new sync architecture
 - All item modifications flow through here
 - Handles both online (immediate sync) and offline (queued) scenarios
 - Automatically retries failed operations
 
 📝 Last Change:
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData
import Combine

/// Central sync engine coordinating local and remote operations with CRDT conflict resolution
@MainActor
final class SyncEngine: ObservableObject, SyncEngineProtocol {
    
    // MARK: - Published State
    
    /// Current sync status for UI feedback
    @Published var syncStatus: SyncStatus = .idle
    
    /// Number of pending operations
    @Published var pendingOperations: Int = 0
    
    // MARK: - Dependencies

    private let repository: ItemsRepository
    private let itemStore: SwiftDataItemStore
    private let operationQueue: SyncOperationQueue
    private let conflictResolver: ConflictResolver
    private let hlcGenerator: HybridLogicalClockGenerator
    private let backoffCalculator: BackoffCalculator
    
    // MARK: - State
    
    /// Timer for background queue processing
    private var queueProcessingTimer: Timer?
    
    /// Track if we're currently processing the queue to avoid concurrent processing
    private var isProcessingQueue: Bool = false
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        repository: ItemsRepository,
        itemStore: SwiftDataItemStore,
        operationQueue: SyncOperationQueue,
        conflictResolver: ConflictResolver,
        hlcGenerator: HybridLogicalClockGenerator,
        backoffCalculator: BackoffCalculator = .default
    ) {
        self.repository = repository
        self.itemStore = itemStore
        self.operationQueue = operationQueue
        self.conflictResolver = conflictResolver
        self.hlcGenerator = hlcGenerator
        self.backoffCalculator = backoffCalculator
        
        // Start background queue processing
        startQueueProcessing()
        
        // Update pending count initially
        updatePendingCount()
    }
    
    // Mit Swift 5.10+ (SE-0371) läuft deinit einer @MainActor-Klasse garantiert auf dem Main Thread.
    // Timer-Callbacks laufen ebenfalls auf RunLoop.main → kein Thread-Race beim Invalidieren.
    deinit {
        queueProcessingTimer?.invalidate()
        queueProcessingTimer = nil
    }
    
    // MARK: - Public API
    
    /// Creates a new item with CRDT metadata.
    ///
    /// The item's UUID is derived deterministically from `(listId, name)` so that
    /// two devices creating an item with the same name in the same list produce
    /// the same UUID. The CRDT LWW-mechanism then resolves the concurrent
    /// creation as a conflict on the same entity instead of creating a duplicate.
    ///
    /// See ADR-005 (Confluence) and FAM-50 for full rationale.
    ///
    /// - Parameter item: The item to create. Its `id` will be replaced with a
    ///   deterministic UUID if `listId` is available.
    func createItem(_ item: ItemModel) async {
        // Derive deterministic UUID from (listId, name) to prevent duplicates
        // on concurrent creation across devices (FAM-50 / ADR-005).
        let canonicalItem: ItemModel
        if let listIdStr = item.listId, let listUUID = UUID(uuidString: listIdStr) {
            let deterministicId = UUID.deterministicItemID(listId: listUUID, name: item.name)
            canonicalItem = ItemModel(
                id: deterministicId.uuidString,
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
                listId: item.listId,
                ownerPublicId: item.ownerPublicId,
                hlcTimestamp: item.hlcTimestamp,
                hlcCounter: item.hlcCounter,
                hlcNodeId: item.hlcNodeId,
                tombstone: item.tombstone,
                lastModifiedBy: item.lastModifiedBy
            )
            logVoid(params: (
                action: "createItem.deterministicId",
                originalId: item.id,
                deterministicId: deterministicId.uuidString,
                name: item.name,
                listId: listIdStr
            ))
        } else {
            // Fallback: no listId available, keep random UUID
            canonicalItem = item
            logVoid(params: (action: "createItem.fallbackRandomId", itemId: item.id, reason: "listId missing"))
        }

        let hlc = hlcGenerator.tick()
        let metadata = CRDTMetadata.created(by: hlcGenerator.nodeId, hlc: hlc)

        // Store locally first with CRDT metadata
        await storeLocally(item: canonicalItem, metadata: metadata)

        // Queue operation for remote sync
        await queueOperation(type: .create, item: canonicalItem, metadata: metadata)

        // Try immediate sync if online
        await processQueue()
    }
    
    /// Updates an existing item with CRDT metadata
    /// - Parameter item: The item to update
    func updateItem(_ item: ItemModel) async {
        // Get existing metadata and update HLC
        guard let uuid = UUID(uuidString: item.id),
              let existingEntity = try? itemStore.fetchItem(id: uuid) else {
            logVoid(params: (action: "updateItem.error", reason: "Item not found in store"))
            return
        }
        
        // Initialize HLC if missing (for old data)
        let existingHLC = HybridLogicalClock(
            timestamp: existingEntity.hlcTimestamp ?? Int64(Date().timeIntervalSince1970 * 1000),
            counter: existingEntity.hlcCounter ?? 0,
            nodeId: existingEntity.hlcNodeId ?? hlcGenerator.nodeId
        )
        
        let newHLC = hlcGenerator.receive(existingHLC)
        let metadata = CRDTMetadata(
            hlc: newHLC,
            tombstone: false,
            lastModifiedBy: hlcGenerator.nodeId
        )
        
        // Store locally first
        await storeLocally(item: item, metadata: metadata)
        
        // Queue operation for remote sync
        await queueOperation(type: .update, item: item, metadata: metadata)
        
        // Try immediate sync if online
        await processQueue()
    }
    
    /// Deletes an item with tombstone
    /// - Parameter item: The item to delete
    func deleteItem(_ item: ItemModel) async {
        guard let uuid = UUID(uuidString: item.id),
              let existingEntity = try? itemStore.fetchItem(id: uuid) else {
            logVoid(params: (action: "deleteItem.error", reason: "Item not found in store"))
            return
        }
        
        // Initialize HLC if missing (for old data)
        let existingHLC = HybridLogicalClock(
            timestamp: existingEntity.hlcTimestamp ?? Int64(Date().timeIntervalSince1970 * 1000),
            counter: existingEntity.hlcCounter ?? 0,
            nodeId: existingEntity.hlcNodeId ?? hlcGenerator.nodeId
        )
        
        let newHLC = hlcGenerator.receive(existingHLC)
        let metadata = CRDTMetadata.deleted(by: hlcGenerator.nodeId, hlc: newHLC)
        
        // Store tombstone locally
        await storeLocally(item: item, metadata: metadata)
        
        // Queue operation for remote sync
        await queueOperation(type: .delete, item: item, metadata: metadata)
        
        // Try immediate sync if online
        await processQueue()
    }
    
    /// Manually triggers queue processing (called on connectivity restore)
    func resumeSync() async {
        await processQueue()
    }
    
    // MARK: - Local Storage
    
    private func storeLocally(item: ItemModel, metadata: CRDTMetadata) async {
        do {
            let entity = try itemStore.upsert(model: item)
            
            // Update CRDT fields (ensure they're always set)
            entity.hlcTimestamp = metadata.hlc.timestamp
            entity.hlcCounter = metadata.hlc.counter
            entity.hlcNodeId = metadata.hlc.nodeId
            entity.tombstone = metadata.tombstone
            entity.lastModifiedBy = metadata.lastModifiedBy
            
            // Set sync status based on operation
            if metadata.tombstone {
                entity.setSyncStatus(.pendingDelete)
            } else {
                // Check if this is new or existing
                if entity.syncStatus == .synced {
                    entity.setSyncStatus(.pendingUpdate)
                } else if entity.syncStatus == .pendingCreate {
                    // Keep as pending create
                } else {
                    entity.setSyncStatus(.pendingUpdate)
                }
            }
            
            try itemStore.save()
            
            logVoid(params: (
                action: "storeLocally",
                itemId: item.id,
                hlcTimestamp: metadata.hlc.timestamp,
                tombstone: metadata.tombstone
            ))
            
            if metadata.tombstone {
                UserLog.Data.itemDeletedLocally()
            } else {
                UserLog.Data.itemStoredLocally(name: item.name)
            }
        } catch {
            logVoid(params: (
                action: "storeLocally.error",
                itemId: item.id,
                error: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Queue Management
    
    private func queueOperation(type: SyncOperationType, item: ItemModel, metadata: CRDTMetadata) async {
        do {
            let operation = try SyncOperation.create(type: type, item: item, metadata: metadata)
            operationQueue.enqueue(operation)
            updatePendingCount()
            
            logVoid(params: (
                action: "queueOperation",
                type: type.rawValue,
                itemId: item.id,
                operationId: operation.id
            ))
            
            UserLog.Sync.operationQueued(type: type.rawValue)
        } catch {
            logVoid(params: (
                action: "queueOperation.error",
                type: type.rawValue,
                itemId: item.id,
                error: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Queue Processing
    
    /// Processes pending operations in the queue
    private func processQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        // Get initial count before starting
        let initialPending = operationQueue.count
        
        syncStatus = .syncing
        
        // User-friendly log when sync starts (only if there are operations)
        if initialPending > 0 {
            UserLog.Sync.syncing(itemCount: initialPending)
        }
        
        while let operation = operationQueue.dequeue() {
            await processOperation(operation)
        }
        
        syncStatus = .idle
        updatePendingCount()
        
        // User-friendly log when sync completes (only if we processed operations)
        if initialPending > 0 {
            UserLog.Sync.completed(itemCount: initialPending)
        }
    }
    
    private func processOperation(_ operation: SyncOperation) async {
        do {
            let item = try operation.decodeItemSnapshot()
            
            logVoid(params: (
                action: "processOperation",
                operationId: operation.id,
                type: operation.type.rawValue,
                itemId: operation.itemId,
                retryCount: operation.retryCount
            ))
            
            UserLog.Sync.processingOperation(type: operation.type.rawValue)
            
            switch operation.type {
            case .create:
                _ = try await repository.createItem(item)
            case .update:
                try await repository.updateItem(item)
            case .delete:
                try await repository.deleteItem(id: item.id, listId: operation.listId)
            }
            
            // Success - remove from queue and update local sync status
            operationQueue.markSuccess(operation.id)
            
            if let uuid = UUID(uuidString: operation.itemId) {
                if operation.type == .delete {
                    try? itemStore.purge(id: uuid)
                } else if let entity = try? itemStore.fetchItem(id: uuid) {
                    entity.setSyncStatus(.synced)
                    try? itemStore.save()
                }
            }
            
            logVoid(params: (
                action: "processOperation.success",
                operationId: operation.id,
                itemId: operation.itemId
            ))
            
            UserLog.Sync.operationCompleted(type: operation.type.rawValue)
            
        } catch {
            // retryCount after this failure = operation.retryCount + 1
            let newRetryCount = operation.retryCount + 1
            let willExceedMaxRetries = backoffCalculator.hasExceededMaxRetries(newRetryCount)

            // Failure – schedule retry with exponential backoff + jitter.
            let backoff = backoffCalculator.delay(for: operation.retryCount)
            operationQueue.updateRetrySchedule(
                operation.id,
                error: error,
                backoff: backoff,
                maxRetries: backoffCalculator.maxRetries
            )

            // Mark local entity as failed once all retries are exhausted.
            if willExceedMaxRetries {
                if let uuid = UUID(uuidString: operation.itemId),
                   let entity = try? itemStore.fetchItem(id: uuid) {
                    entity.setSyncStatus(.failed)
                    try? itemStore.save()
                }
                UserLog.Sync.failed(reason: "Maximale Wiederholungen erreicht")
            }

            logVoid(params: (
                action: "processOperation.error",
                operationId: operation.id,
                itemId: operation.itemId,
                retryCount: newRetryCount,
                backoff: backoff,
                error: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Background Processing
    
    private func startQueueProcessing() {
        // Process queue every 5 seconds
        queueProcessingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.processQueue()
            }
        }
    }
    
    private func stopQueueProcessing() {
        queueProcessingTimer?.invalidate()
        queueProcessingTimer = nil
    }
    
    private func updatePendingCount() {
        pendingOperations = operationQueue.count
    }
    
    // MARK: - Lifecycle Management
    
    /// Pauses background queue processing (called when app enters background)
    func pause() {
        stopQueueProcessing()
        syncStatus = .paused
    }
    
    /// Resumes background queue processing (called when app becomes active)
    func resume() {
        startQueueProcessing()
        syncStatus = .idle
        Task {
            await processQueue()
        }
    }
}


