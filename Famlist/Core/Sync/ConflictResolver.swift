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
            // If both are tombstones, compare HLC to pick the more recent deletion
            // Otherwise, the tombstone always wins over non-tombstone
            let useLocal: Bool
            if localMeta.tombstone && remoteMeta.tombstone {
                // Both deleted: use Last-Write-Wins based on HLC
                useLocal = remoteMeta.hlc.happenedBefore(localMeta.hlc)
            } else {
                // Only one is deleted: tombstone always wins
                useLocal = localMeta.tombstone
            }
            let winningMeta = useLocal ? localMeta : remoteMeta
            let winningItem = useLocal ? local : remote
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

        // Merge each field independently based on its HLC using the generic helper below.
        mergeField("name",              remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.name },               set: { $0.name = $1 })
        mergeField("units",             remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.units },              set: { $0.units = $1 })
        mergeField("measure",           remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.measure },            set: { $0.measure = $1 })
        mergeField("price",             remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.price },              set: { $0.price = $1 })
        mergeField("isChecked",         remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.isChecked },          set: { $0.isChecked = $1 })
        mergeField("category",          remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.category },           set: { $0.category = $1 })
        mergeField("productDescription",remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.productDescription }, set: { $0.productDescription = $1 })
        mergeField("brand",             remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.brand },              set: { $0.brand = $1 })
        mergeField("imageData",         remote: remote, localFields: localFields, remoteFields: remoteFields, merged: &merged, mergedFields: &mergedFields, get: { $0.imageData },          set: { $0.imageData = $1 })

        return (merged, mergedFields)
    }
    
    // MARK: - Helpers

    /// Wendet einen Remote-Feldwert auf `merged` an, wenn der Remote-HLC neuer ist als der lokale.
    private func mergeField<T>(
        _ key: String,
        remote: ItemModel,
        localFields: FieldLevelCRDT,
        remoteFields: FieldLevelCRDT,
        merged: inout ItemModel,
        mergedFields: inout FieldLevelCRDT,
        get: (ItemModel) -> T,
        set: (inout ItemModel, T) -> Void
    ) {
        guard let remoteHLC = remoteFields.getHLC(for: key),
              let localHLC = localFields.getHLC(for: key),
              localHLC.happenedBefore(remoteHLC) else { return }
        set(&merged, get(remote))
        mergedFields.updateField(key, hlc: remoteHLC, modifiedBy: remoteFields.fields[key]?.lastModifiedBy ?? "")
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

