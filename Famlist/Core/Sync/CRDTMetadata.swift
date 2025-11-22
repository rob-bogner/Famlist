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

/// Field-level CRDT metadata for fine-grained conflict resolution
/// Each field of an item can be independently versioned
struct FieldMetadata: Codable, Equatable, Hashable {
    /// Field name (e.g., "name", "units", "isChecked")
    let fieldName: String
    
    /// HLC for this specific field
    var hlc: HybridLogicalClock
    
    /// Who last modified this field
    var lastModifiedBy: String
    
    init(fieldName: String, hlc: HybridLogicalClock, lastModifiedBy: String) {
        self.fieldName = fieldName
        self.hlc = hlc
        self.lastModifiedBy = lastModifiedBy
    }
}

/// Container for field-level metadata (optional advanced feature)
struct FieldLevelCRDT: Codable, Equatable, Hashable {
    /// Dictionary mapping field names to their metadata
    var fields: [String: FieldMetadata]
    
    init(fields: [String: FieldMetadata] = [:]) {
        self.fields = fields
    }
    
    /// Updates metadata for a specific field
    mutating func updateField(_ fieldName: String, hlc: HybridLogicalClock, modifiedBy: String) {
        fields[fieldName] = FieldMetadata(
            fieldName: fieldName,
            hlc: hlc,
            lastModifiedBy: modifiedBy
        )
    }
    
    /// Gets the HLC for a specific field, or nil if not tracked
    func getHLC(for fieldName: String) -> HybridLogicalClock? {
        return fields[fieldName]?.hlc
    }
}

