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

    // MARK: - Init

    /// - Parameter repository: Repository that receives mutations and broadcasts changes.
    ///   Pass `PreviewItemsRepository` for SwiftUI previews.
    init(repository: ItemsRepository) {
        self.repository = repository
    }

    // MARK: - SyncEngineProtocol

    func createItem(_ item: ItemModel) async {
        _ = try? await repository.createItem(item)
    }

    func updateItem(_ item: ItemModel) async {
        try? await repository.updateItem(item)
    }

    func deleteItem(_ item: ItemModel) async {
        guard let listIdStr = item.listId, let listUUID = UUID(uuidString: listIdStr) else { return }
        try? await repository.deleteItem(id: item.id, listId: listUUID)
    }

    /// No-op: preview mode has no operation queue to flush.
    func resumeSync() async {}

    /// No-op: preview mode has no failed operations to retry.
    func retryItem(_ item: ItemModel) async {}

    /// No-op: preview mode has no operation queue for bulk imports.
    func applyBulkItems(_ targets: [ImportTarget]) async {}

    /// No-op: preview mode has no retry queue for bulk toggle fallback.
    func enqueueBulkToggleFallback(_ items: [ItemModel]) async {}

    /// No-op: preview mode has no retry queue for bulk delete fallback.
    func enqueueBulkDeleteFallback(_ items: [ItemModel]) async {}

    /// Returns a valid wall-clock HLC for previews and tests.
    /// No CRDT monotonicity guarantee — intentional, preview mode only.
    func hlcForUpdate(currentTimestamp: Int64?, currentCounter: Int?, currentNodeId: String?) -> HybridLogicalClock {
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        return HybridLogicalClock(timestamp: ts, counter: 0, nodeId: "preview-node")
    }
}
