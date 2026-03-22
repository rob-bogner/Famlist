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
 - shouldApplyRemote(): public boolean API, delegates to winner()

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

    /// Returns whether the remote version should replace the local version.
    /// Delegates to `winner(localMeta:remoteMeta:)` — the single merge decision point.
    ///
    /// This also protects local tombstones: a non-tombstoned remote can never
    /// overwrite a locally-tombstoned item, regardless of HLC ordering.
    func shouldApplyRemote(localMeta: CRDTMetadata, remoteMeta: CRDTMetadata) -> Bool {
        return winner(localMeta: localMeta, remoteMeta: remoteMeta) == remoteMeta
    }
}

