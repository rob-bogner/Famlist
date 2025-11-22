/*
 SyncMonitor.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Performance monitoring and metrics collection for sync operations.
 
 🛠 Includes:
 - Sync latency tracking
 - Conflict rate measurement
 - Queue depth monitoring
 
 🔰 Notes for Beginners:
 - Helps identify performance bottlenecks
 - Metrics can be exposed to analytics or debugging UI
 
 📝 Last Change:
 - Initial implementation for performance monitoring
 ------------------------------------------------------------------------
*/

import Foundation
import Combine

/// Monitors sync performance and collects metrics
@MainActor
final class SyncMonitor: ObservableObject {
    
    // MARK: - Published Metrics
    
    /// Whether sync is currently active
    @Published var isSyncing: Bool = false
    
    /// Last sync error message
    @Published var lastError: String? = nil
    
    /// Last successful sync timestamp
    @Published var lastSuccessfulSync: Date? = nil
    
    /// Average sync latency in milliseconds
    @Published var averageSyncLatency: Double = 0
    
    /// Average latency for compatibility with indicator
    var averageLatency: Double { averageSyncLatency }
    
    /// Number of conflicts resolved
    @Published var conflictCount: Int = 0
    
    /// Current operation queue depth
    @Published var queueDepth: Int = 0
    
    /// Pending operations count (alias for queueDepth)
    var pendingOperations: Int { queueDepth }
    
    /// Total operations processed
    @Published var totalOperations: Int = 0
    
    /// Failed operations count
    @Published var failedOperations: Int = 0
    
    // MARK: - Internal State
    
    private var latencySamples: [TimeInterval] = []
    private let maxSamples = 100
    
    // MARK: - Recording
    
    /// Records the start of a sync operation
    /// - Returns: Operation ID for tracking
    func startOperation() -> UUID {
        isSyncing = true
        return UUID()
    }
    
    /// Records completion of a sync operation
    /// - Parameters:
    ///   - operationId: ID from startOperation
    ///   - success: Whether operation succeeded
    func endOperation(_ operationId: UUID, success: Bool, latency: TimeInterval) {
        totalOperations += 1
        isSyncing = false
        
        if success {
            lastSuccessfulSync = Date()
            lastError = nil
        } else {
            failedOperations += 1
            lastError = "Sync operation failed"
        }
        
        // Record latency
        latencySamples.append(latency)
        if latencySamples.count > maxSamples {
            latencySamples.removeFirst()
        }
        
        // Update average
        averageSyncLatency = latencySamples.reduce(0, +) / Double(latencySamples.count) * 1000
        
        logVoid(params: (
            action: "syncOperation",
            operationId: operationId,
            success: success,
            latencyMs: averageSyncLatency
        ))
    }
    
    /// Records a conflict resolution
    func recordConflict() {
        conflictCount += 1
        
        logVoid(params: (
            action: "conflictResolved",
            totalConflicts: conflictCount
        ))
    }
    
    /// Updates the current queue depth
    /// - Parameter depth: Number of pending operations
    func updateQueueDepth(_ depth: Int) {
        queueDepth = depth
    }
    
    /// Resets all metrics
    func reset() {
        isSyncing = false
        lastError = nil
        lastSuccessfulSync = nil
        averageSyncLatency = 0
        conflictCount = 0
        queueDepth = 0
        totalOperations = 0
        failedOperations = 0
        latencySamples.removeAll()
    }
    
    // MARK: - Computed Metrics
    
    /// Success rate as percentage
    var successRate: Double {
        guard totalOperations > 0 else { return 100.0 }
        return Double(totalOperations - failedOperations) / Double(totalOperations) * 100.0
    }
    
    /// Conflict rate per 100 operations
    var conflictRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(conflictCount) / Double(totalOperations) * 100.0
    }
}

