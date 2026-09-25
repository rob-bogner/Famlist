/*
 PreviewSyncEngine.swift
 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lightweight SyncEngineProtocol implementation for SwiftUI previews
   and scenarios where a full SyncEngine is not available (e.g. when
   Supabase config is absent).

 🛠 Includes:
 - PreviewSyncEngine: delegates CRUD operations directly to an ItemsRepository.
   For PreviewItemsRepository this causes an immediate broadcast() → observeTask
   snapshot → UI update, giving the same responsiveness as the real SyncEngine.

 🔰 Notes for Beginners:
 - No CRDT metadata, no HLC, no operation queue — this is intentional.
   Offline-First guarantees are only required in production where the real
   SyncEngine is always injected.
 - listId is resolved from ItemModel.listId; if missing the operation is a no-op.

 📝 Last Change:
 - Initial creation (FAM-66): replaces the legacy `else` branches in ListViewModel.
 ------------------------------------------------------------------------
 */

import Foundation

// MARK: - PreviewSyncEngine

/// In-memory SyncEngine substitute used in SwiftUI previews and the Supabase-less
/// fallback branch of FamlistApp. Delegates mutations to an ItemsRepository so that
/// repository broadcasts propagate to ListViewModel's observeTask.
@MainActor
final class PreviewSyncEngine: SyncEngineProtocol {

    // MARK: - Dependencies

    private let repository: ItemsRepository
    private let clock = HybridLogicalClockGenerator(nodeId: "preview")

    // MARK: - Init

    /// - Parameter repository: Repository that receives mutations and broadcasts changes.
    ///   Pass `PreviewItemsRepository` for SwiftUI previews.
    init(repository: ItemsRepository) {
        self.repository = repository
    }

    // MARK: - SyncEngineProtocol

    func createItem(_ item: ItemModel) async { await send([item], tombstone: false) }
    func updateItem(_ item: ItemModel) async { await send([item], tombstone: false) }
    func deleteItem(_ item: ItemModel) async { await send([item], tombstone: true) }
    func deleteItems(_ items: [ItemModel]) async { await send(items, tombstone: true) }
    func applyLocalChanges(_ items: [ItemModel]) async { await send(items, tombstone: false) }

    /// No-op: preview mode has no operation queue to flush.
    func resumeSync() async {}

    /// No-op: preview mode has no failed operations to retry.
    func retryItem(_ item: ItemModel) async {}

    /// No-op: preview mode has no operation queue for bulk imports.
    func applyBulkItems(_ targets: [ImportTarget]) async {}

    /// Direkt an das In-Memory-Repository, mit neuer HLC (gleiche Regel wie die echte Engine).
    private func send(_ items: [ItemModel], tombstone: Bool) async {
        let requests = items.map { item -> ItemUpsertRequest in
            var stamped = item
            let hlc = clock.tick()
            stamped.hlcTimestamp = hlc.timestamp
            stamped.hlcCounter = hlc.counter
            stamped.hlcNodeId = hlc.nodeId
            stamped.tombstone = tombstone
            return ItemUpsertRequest(item: stamped, includeImage: true)
        }
        _ = try? await repository.upsertItems(requests)
    }
}
