/*
 OperationQueue.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Manages persistent queue of sync operations using SwiftData.
 
 🛠 Includes:
 - enqueue/dequeue operations
 - Retry scheduling with exponential backoff
 - Query methods for operation status
 
 🔰 Notes for Beginners:
 - Operations persist across app restarts
 - Failed operations stay in queue for automatic retry
 - Queue processes operations in FIFO order (oldest first)
 
 📝 Last Change:
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Manages a persistent queue of sync operations backed by SwiftData
@MainActor
final class SyncOperationQueue {
    
    // MARK: - Dependencies
    
    private let context: ModelContext
    
    // MARK: - Initialization
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Queue Operations
    
    /// Adds a new operation to the queue
    /// - Parameter operation: The sync operation to enqueue
    func enqueue(_ operation: SyncOperation) {
        context.insert(operation)
        do {
            try context.save()
            logVoid(params: (
                action: "enqueueOperation",
                operationId: operation.id,
                type: operation.type.rawValue,
                itemId: operation.itemId
            ))
        } catch {
            logVoid(params: (
                action: "enqueueOperation.error",
                error: error.localizedDescription
            ))
        }
    }
    
    /// Gets the next operation ready for processing (FIFO, considering retry delays)
    /// - Returns: Next operation to process, or nil if queue is empty or all operations are scheduled for later
    func dequeue() -> SyncOperation? {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                !operation.hasFailed
            },
            sortBy: [SortDescriptor(\SyncOperation.createdAt, order: .forward)]
        )
        
        do {
            let operations = try context.fetch(descriptor)
            
            // Find first operation ready for retry
            return operations.first { $0.isReadyForRetry }
        } catch {
            logVoid(params: (
                action: "dequeueOperation.error",
                error: error.localizedDescription
            ))
            return nil
        }
    }
    
    /// Gets all pending operations (for monitoring/debugging)
    /// - Returns: Array of all operations in queue
    func peek() -> [SyncOperation] {
        let descriptor = FetchDescriptor<SyncOperation>(
            sortBy: [SortDescriptor(\SyncOperation.createdAt, order: .forward)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logVoid(params: (
                action: "peekQueue.error",
                error: error.localizedDescription
            ))
            return []
        }
    }
    
    /// Gets pending operations for a specific list
    /// - Parameter listId: UUID of the list
    /// - Returns: Operations affecting that list
    func operations(for listId: UUID) -> [SyncOperation] {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { operation in
                operation.listId == listId && !operation.hasFailed
            },
            sortBy: [SortDescriptor(\SyncOperation.createdAt, order: .forward)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logVoid(params: (
                action: "operationsForList.error",
                error: error.localizedDescription
            ))
            return []
        }
    }
    
    /// Removes an operation from the queue (after successful completion)
    /// - Parameter operationId: UUID of the operation to remove
    func remove(_ operationId: UUID) {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.id == operationId }
        )
        
        do {
            let operations = try context.fetch(descriptor)
            for operation in operations {
                context.delete(operation)
            }
            try context.save()
            
            logVoid(params: (
                action: "removeOperation",
                operationId: operationId
            ))
        } catch {
            logVoid(params: (
                action: "removeOperation.error",
                operationId: operationId,
                error: error.localizedDescription
            ))
        }
    }
    
    /// Updates retry schedule for an operation after a failure
    /// - Parameters:
    ///   - operationId: UUID of the operation
    ///   - error: The error that occurred
    ///   - backoff: Time interval to wait before next retry
    ///   - maxRetries: Maximum allowed retries before marking as permanently failed.
    func updateRetrySchedule(_ operationId: UUID, error: Error, backoff: TimeInterval, maxRetries: Int = BackoffCalculator.default.maxRetries) {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.id == operationId }
        )

        do {
            let operations = try context.fetch(descriptor)
            guard let operation = operations.first else { return }

            operation.recordFailure(error: error, backoff: backoff, maxRetries: maxRetries)
            try context.save()
            
            logVoid(params: (
                action: "updateRetrySchedule",
                operationId: operationId,
                retryCount: operation.retryCount,
                nextRetryAt: operation.nextRetryAt?.description ?? "nil",
                hasFailed: operation.hasFailed
            ))
        } catch {
            logVoid(params: (
                action: "updateRetrySchedule.error",
                operationId: operationId,
                error: error.localizedDescription
            ))
        }
    }
    
    /// Marks an operation as successfully completed
    /// - Parameter operationId: UUID of the operation
    func markSuccess(_ operationId: UUID) {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.id == operationId }
        )
        
        do {
            let operations = try context.fetch(descriptor)
            guard let operation = operations.first else { return }
            
            operation.markSuccess()
            try context.save()
            
            // Remove from queue after success
            remove(operationId)
        } catch {
            logVoid(params: (
                action: "markSuccess.error",
                operationId: operationId,
                error: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Queue Status
    
    /// Returns the number of pending operations
    var count: Int {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { !$0.hasFailed }
        )
        
        do {
            let operations = try context.fetch(descriptor)
            return operations.count
        } catch {
            return 0
        }
    }
    
    /// Returns the number of failed operations
    var failedCount: Int {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.hasFailed }
        )
        
        do {
            let operations = try context.fetch(descriptor)
            return operations.count
        } catch {
            return 0
        }
    }
    
    /// Resets a permanently-failed operation so it is eligible for retry.
    /// - Parameter itemId: The item ID string whose failed operation should be reset.
    func resetFailedOperation(itemId: String) {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.itemId == itemId && $0.hasFailed }
        )

        do {
            let operations = try context.fetch(descriptor)
            for operation in operations {
                operation.hasFailed = false
                operation.retryCount = 0
                operation.nextRetryAt = nil
                operation.lastErrorMessage = nil
            }
            try context.save()

            logVoid(params: (
                action: "resetFailedOperation",
                itemId: itemId,
                count: operations.count
            ))
        } catch {
            logVoid(params: (
                action: "resetFailedOperation.error",
                itemId: itemId,
                error: error.localizedDescription
            ))
        }
    }

    /// Clears all failed operations (for manual cleanup)
    func clearFailed() {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.hasFailed }
        )
        
        do {
            let operations = try context.fetch(descriptor)
            for operation in operations {
                context.delete(operation)
            }
            try context.save()
            
            logVoid(params: (
                action: "clearFailedOperations",
                count: operations.count
            ))
        } catch {
            logVoid(params: (
                action: "clearFailedOperations.error",
                error: error.localizedDescription
            ))
        }
    }
}

