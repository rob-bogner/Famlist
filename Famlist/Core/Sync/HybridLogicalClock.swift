/*
 HybridLogicalClock.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Implementation of Hybrid Logical Clock (HLC) for causally consistent timestamps.
 
 🛠 Includes:
 - HLC struct with timestamp, counter, and nodeId
 - Comparison logic for causal ordering
 - Generator for creating new HLCs
 
 🔰 Notes for Beginners:
 - HLC combines physical time with logical counters to ensure causal consistency
 - Even if device clocks drift, HLC maintains monotonic ordering
 - Critical for CRDT conflict resolution in distributed systems
 
 📝 Last Change:
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation

/// Hybrid Logical Clock providing causally consistent timestamps across devices.
/// Based on the algorithm from: "Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases"
struct HybridLogicalClock: Codable, Equatable, Hashable {
    /// Physical timestamp in milliseconds since epoch
    let timestamp: Int64
    
    /// Logical counter for disambiguating events at the same timestamp
    let counter: Int
    
    /// Unique identifier for the device/node that created this clock
    let nodeId: String
    
    // MARK: - Initialization
    
    init(timestamp: Int64, counter: Int, nodeId: String) {
        self.timestamp = timestamp
        self.counter = counter
        self.nodeId = nodeId
    }
    
    // MARK: - Comparison
    
    /// Compares two HLCs for causal ordering.
    /// Returns true if self happened before other.
    func happenedBefore(_ other: HybridLogicalClock) -> Bool {
        if timestamp != other.timestamp {
            return timestamp < other.timestamp
        }
        if counter != other.counter {
            return counter < other.counter
        }
        // At identical timestamp and counter, use nodeId for deterministic ordering
        return nodeId < other.nodeId
    }
    
    /// Returns the maximum (most recent) of two HLCs
    static func max(_ lhs: HybridLogicalClock, _ rhs: HybridLogicalClock) -> HybridLogicalClock {
        if lhs.happenedBefore(rhs) {
            return rhs
        }
        return lhs
    }
}

// MARK: - Comparable

extension HybridLogicalClock: Comparable {
    static func < (lhs: HybridLogicalClock, rhs: HybridLogicalClock) -> Bool {
        return lhs.happenedBefore(rhs)
    }
}

// MARK: - Generator

/// Generates HLC timestamps maintaining causal consistency with observed clocks
@MainActor
final class HybridLogicalClockGenerator {
    
    /// Last generated HLC to ensure monotonicity
    private var lastHLC: HybridLogicalClock
    
    /// Unique identifier for this device/node
    let nodeId: String
    
    // MARK: - Initialization
    
    /// Creates a new HLC generator with a unique node identifier
    /// - Parameter nodeId: Unique device/user identifier (defaults to random UUID)
    init(nodeId: String? = nil) {
        // Use provided nodeId or generate a random UUID
        // Note: UIDevice.identifierForVendor requires MainActor, so we default to UUID
        self.nodeId = nodeId ?? UUID().uuidString
        let now = Self.currentTimestamp()
        self.lastHLC = HybridLogicalClock(timestamp: now, counter: 0, nodeId: self.nodeId)
    }
    
    // MARK: - Clock Generation
    
    /// Generates a new HLC for a local event
    /// - Returns: New HLC that is guaranteed to be greater than all previously generated HLCs
    func tick() -> HybridLogicalClock {
        let physicalTime = Self.currentTimestamp()
        
        if physicalTime > lastHLC.timestamp {
            // Physical clock advanced, reset counter
            lastHLC = HybridLogicalClock(
                timestamp: physicalTime,
                counter: 0,
                nodeId: nodeId
            )
        } else {
            // Physical clock hasn't advanced or went backwards, increment counter
            lastHLC = HybridLogicalClock(
                timestamp: lastHLC.timestamp,
                counter: lastHLC.counter + 1,
                nodeId: nodeId
            )
        }
        
        return lastHLC
    }
    
    /// Receives a remote HLC and generates a new HLC that is causally after it
    /// - Parameter remoteHLC: HLC from a remote event
    /// - Returns: New HLC that happened-after both local and remote HLCs
    func receive(_ remoteHLC: HybridLogicalClock) -> HybridLogicalClock {
        let physicalTime = Self.currentTimestamp()
        
        let maxTimestamp = max(physicalTime, max(lastHLC.timestamp, remoteHLC.timestamp))
        
        let newCounter: Int
        if maxTimestamp == lastHLC.timestamp && maxTimestamp == remoteHLC.timestamp {
            // Both local and remote are at this timestamp
            newCounter = max(lastHLC.counter, remoteHLC.counter) + 1
        } else if maxTimestamp == lastHLC.timestamp {
            // Only local is at this timestamp
            newCounter = lastHLC.counter + 1
        } else if maxTimestamp == remoteHLC.timestamp {
            // Only remote is at this timestamp
            newCounter = remoteHLC.counter + 1
        } else {
            // Physical time advanced beyond both
            newCounter = 0
        }
        
        lastHLC = HybridLogicalClock(
            timestamp: maxTimestamp,
            counter: newCounter,
            nodeId: nodeId
        )
        
        return lastHLC
    }
    
    // MARK: - Helpers
    
    /// Returns current physical timestamp in milliseconds
    private static func currentTimestamp() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

