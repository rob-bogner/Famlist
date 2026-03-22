/*
 CRDTMetadata.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - CRDT metadata container for tracking causality and conflict resolution.
 
 🛠 Includes:
 - CRDTMetadata struct with HLC, tombstone flag, and modifier info
 - Field-level metadata for fine-grained CRDT
 
 🔰 Notes for Beginners:
 - This metadata enables Last-Write-Wins Element-Set (LWW-Element-Set) CRDT
 - Each field can have its own HLC for field-level conflict resolution
 - Tombstones mark deleted items while preserving causal history
 
 📝 Last Change:
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation

/// CRDT metadata for tracking causality and enabling conflict resolution
struct CRDTMetadata: Codable, Equatable, Hashable {
    /// Hybrid Logical Clock representing when this version was created
    var hlc: HybridLogicalClock
    
    /// Indicates if this item has been deleted (tombstone for eventual consistency)
    var tombstone: Bool
    
    /// Identifier of the user/device that last modified this item
    var lastModifiedBy: String
    
    // MARK: - Initialization
    
    init(hlc: HybridLogicalClock, tombstone: Bool = false, lastModifiedBy: String) {
        self.hlc = hlc
        self.tombstone = tombstone
        self.lastModifiedBy = lastModifiedBy
    }
    
    /// Creates metadata for a newly created item
    static func created(by nodeId: String, hlc: HybridLogicalClock) -> CRDTMetadata {
        return CRDTMetadata(
            hlc: hlc,
            tombstone: false,
            lastModifiedBy: nodeId
        )
    }
    
    /// Creates metadata for a deleted item (tombstone)
    static func deleted(by nodeId: String, hlc: HybridLogicalClock) -> CRDTMetadata {
        return CRDTMetadata(
            hlc: hlc,
            tombstone: true,
            lastModifiedBy: nodeId
        )
    }
}


