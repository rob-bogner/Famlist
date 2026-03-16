/*
 ConflictResolver.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 16.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - CRDT-based conflict resolution using Last-Write-Wins semantics with HLC.
 - Single merge decision point: private winner(localMeta:remoteMeta:)
 - Both resolve() and shouldApplyRemote() delegate to winner().

 🛠 Includes:
 - winner(): private core — tombstone + HLC rules
 - resolve(): public full-result API (item + metadata)
 - shouldApplyRemote(): public boolean convenience, delegates to winner()
 - resolveFieldLevel(): optional field-level merge (advanced, not used in main path)

 🔰 Notes for Beginners:
 - Tombstones (deletions) always win to ensure eventual consistency
 - Local tombstones are protected: a newer non-tombstoned remote can never un-delete
 - Deterministic resolution ensures all devices converge to same state

 📝 Last Change:
 - FAM-68: Extracted winner() as single merge core; fixed tombstone-protection bug
   in shouldApplyRemote(); resolve() now delegates instead of reimplementing
 ------------------------------------------------------------------------
*/

import Foundation

/// Resolves conflicts between local and remote item versions using CRDT semantics
@MainActor
final class ConflictResolver {

    // MARK: - Single Merge Core

    /// The single merge decision point. All conflict resolution delegates here.
    ///
    /// Rules (in priority order):
    /// 1. If either side is a tombstone, the tombstone wins.
    ///    If both are tombstones, the causally later one wins.
    /// 2. Last-Write-Wins via HLC.
    ///
    /// - Returns: The winning `CRDTMetadata` (local or remote).
    private func winner(localMeta: CRDTMetadata, remoteMeta: CRDTMetadata) -> CRDTMetadata {
        if localMeta.tombstone || remoteMeta.tombstone {
            if localMeta.tombstone && remoteMeta.tombstone {
                return remoteMeta.hlc.happenedBefore(localMeta.hlc) ? localMeta : remoteMeta
            }
            return localMeta.tombstone ? localMeta : remoteMeta
        }
        return remoteMeta.hlc.happenedBefore(localMeta.hlc) ? localMeta : remoteMeta
    }

    // MARK: - Public API

    /// Merges two ItemModels using Last-Write-Wins Element-Set CRDT semantics.
    /// Delegates the winner decision to `winner(localMeta:remoteMeta:)`.
    ///
    /// - Returns: The winning `(item, metadata)` pair.
    func resolve(
        local: ItemModel,
        remote: ItemModel,
        localMeta: CRDTMetadata,
        remoteMeta: CRDTMetadata
    ) -> (item: ItemModel, metadata: CRDTMetadata) {
        let winningMeta = winner(localMeta: localMeta, remoteMeta: remoteMeta)
        return winningMeta == localMeta ? (local, localMeta) : (remote, remoteMeta)
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

    /// Returns whether the remote version should replace the local version.
    /// Delegates to `winner(localMeta:remoteMeta:)` — the single merge decision point.
    ///
    /// This also protects local tombstones: a non-tombstoned remote can never
    /// overwrite a locally-tombstoned item, regardless of HLC ordering.
    func shouldApplyRemote(localMeta: CRDTMetadata, remoteMeta: CRDTMetadata) -> Bool {
        return winner(localMeta: localMeta, remoteMeta: remoteMeta) == remoteMeta
    }
}

