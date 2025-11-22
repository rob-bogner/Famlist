/*
 ConflictResolver.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - CRDT-based conflict resolution using Last-Write-Wins semantics with HLC.
 
 🛠 Includes:
 - resolve() method merging local and remote ItemModels
 - Field-level conflict resolution
 - Tombstone handling for deletions
 
 🔰 Notes for Beginners:
 - Uses HLC to determine which version of each field is newer
 - Tombstones (deletions) always win to ensure eventual consistency
 - Deterministic resolution ensures all devices converge to same state
 
 📝 Last Change:
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation

/// Resolves conflicts between local and remote item versions using CRDT semantics
@MainActor
final class ConflictResolver {
    
    // MARK: - Resolution Strategy
    
    /// Merges two ItemModels using Last-Write-Wins Element-Set CRDT semantics
    /// - Parameters:
    ///   - local: Local version of the item
    ///   - remote: Remote version of the item
    ///   - localMeta: CRDT metadata for local version
    ///   - remoteMeta: CRDT metadata for remote version
    /// - Returns: Merged item with the most recent values for each field
    func resolve(
        local: ItemModel,
        remote: ItemModel,
        localMeta: CRDTMetadata,
        remoteMeta: CRDTMetadata
    ) -> (item: ItemModel, metadata: CRDTMetadata) {
        
        // RULE 1: Tombstones always win (deletions propagate)
        if localMeta.tombstone || remoteMeta.tombstone {
            let winningMeta = localMeta.tombstone ? localMeta : remoteMeta
            let winningItem = localMeta.tombstone ? local : remote
            return (winningItem, winningMeta)
        }
        
        // RULE 2: Use HLC to determine which version is newer
        let useLocal = remoteMeta.hlc.happenedBefore(localMeta.hlc)
        
        if useLocal {
            return (local, localMeta)
        } else {
            return (remote, remoteMeta)
        }
    }
    
    /// Performs field-level merge for more granular conflict resolution (optional advanced feature)
    /// - Parameters:
    ///   - local: Local version of the item
    ///   - remote: Remote version of the item
    ///   - localFields: Field-level CRDT metadata for local
    ///   - remoteFields: Field-level CRDT metadata for remote
    /// - Returns: Merged item with field-by-field resolution
    func resolveFieldLevel(
        local: ItemModel,
        remote: ItemModel,
        localFields: FieldLevelCRDT,
        remoteFields: FieldLevelCRDT
    ) -> (item: ItemModel, fields: FieldLevelCRDT) {
        
        var merged = local
        var mergedFields = localFields
        
        // Merge each field independently based on its HLC
        
        // Name
        if let remoteHLC = remoteFields.getHLC(for: "name"),
           let localHLC = localFields.getHLC(for: "name") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.name = remote.name
                mergedFields.updateField("name", hlc: remoteHLC, modifiedBy: remoteFields.fields["name"]?.lastModifiedBy ?? "")
            }
        }
        
        // Units
        if let remoteHLC = remoteFields.getHLC(for: "units"),
           let localHLC = localFields.getHLC(for: "units") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.units = remote.units
                mergedFields.updateField("units", hlc: remoteHLC, modifiedBy: remoteFields.fields["units"]?.lastModifiedBy ?? "")
            }
        }
        
        // Measure
        if let remoteHLC = remoteFields.getHLC(for: "measure"),
           let localHLC = localFields.getHLC(for: "measure") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.measure = remote.measure
                mergedFields.updateField("measure", hlc: remoteHLC, modifiedBy: remoteFields.fields["measure"]?.lastModifiedBy ?? "")
            }
        }
        
        // Price
        if let remoteHLC = remoteFields.getHLC(for: "price"),
           let localHLC = localFields.getHLC(for: "price") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.price = remote.price
                mergedFields.updateField("price", hlc: remoteHLC, modifiedBy: remoteFields.fields["price"]?.lastModifiedBy ?? "")
            }
        }
        
        // IsChecked (often changed independently by different users)
        if let remoteHLC = remoteFields.getHLC(for: "isChecked"),
           let localHLC = localFields.getHLC(for: "isChecked") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.isChecked = remote.isChecked
                mergedFields.updateField("isChecked", hlc: remoteHLC, modifiedBy: remoteFields.fields["isChecked"]?.lastModifiedBy ?? "")
            }
        }
        
        // Category
        if let remoteHLC = remoteFields.getHLC(for: "category"),
           let localHLC = localFields.getHLC(for: "category") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.category = remote.category
                mergedFields.updateField("category", hlc: remoteHLC, modifiedBy: remoteFields.fields["category"]?.lastModifiedBy ?? "")
            }
        }
        
        // Product Description
        if let remoteHLC = remoteFields.getHLC(for: "productDescription"),
           let localHLC = localFields.getHLC(for: "productDescription") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.productDescription = remote.productDescription
                mergedFields.updateField("productDescription", hlc: remoteHLC, modifiedBy: remoteFields.fields["productDescription"]?.lastModifiedBy ?? "")
            }
        }
        
        // Brand
        if let remoteHLC = remoteFields.getHLC(for: "brand"),
           let localHLC = localFields.getHLC(for: "brand") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.brand = remote.brand
                mergedFields.updateField("brand", hlc: remoteHLC, modifiedBy: remoteFields.fields["brand"]?.lastModifiedBy ?? "")
            }
        }
        
        // ImageData
        if let remoteHLC = remoteFields.getHLC(for: "imageData"),
           let localHLC = localFields.getHLC(for: "imageData") {
            if localHLC.happenedBefore(remoteHLC) {
                merged.imageData = remote.imageData
                mergedFields.updateField("imageData", hlc: remoteHLC, modifiedBy: remoteFields.fields["imageData"]?.lastModifiedBy ?? "")
            }
        }
        
        return (merged, mergedFields)
    }
    
    /// Determines if a remote update should be applied given local state
    /// - Parameters:
    ///   - localMeta: Local CRDT metadata
    ///   - remoteMeta: Remote CRDT metadata
    /// - Returns: True if remote should be applied, false if local is newer
    func shouldApplyRemote(localMeta: CRDTMetadata, remoteMeta: CRDTMetadata) -> Bool {
        // Tombstones always apply
        if remoteMeta.tombstone {
            return true
        }
        
        // Don't overwrite with older data
        return localMeta.hlc.happenedBefore(remoteMeta.hlc)
    }
}

