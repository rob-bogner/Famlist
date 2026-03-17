/*
 SyncEngineProtocol.swift
 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Protocol abstracting SyncEngine for dependency injection and testability.
 - Allows SwiftUI previews and unit tests to inject a lightweight stub
   without instantiating the full CRDT/Supabase stack.

 🛠 Includes:
 - SyncEngineProtocol: minimal surface used by ListViewModel (CRUD + resumeSync).

 🔰 Notes for Beginners:
 - The concrete SyncEngine class conforms via extension in SyncEngine.swift.
 - PreviewSyncEngine provides an in-memory implementation for previews/tests.

 📝 Last Change:
 - Initial creation (FAM-66): extracted from SyncEngine to enable protocol-based DI.
 ------------------------------------------------------------------------
 */

import Foundation

// MARK: - Protocol

/// Minimal contract that ListViewModel requires from the sync subsystem.
/// Conformers: `SyncEngine` (production), `PreviewSyncEngine` (previews/tests).
@MainActor
protocol SyncEngineProtocol: AnyObject {

    /// Creates an item locally and queues it for remote sync.
    func createItem(_ item: ItemModel) async

    /// Updates an item locally and queues the change for remote sync.
    func updateItem(_ item: ItemModel) async

    /// Soft-deletes an item locally and queues the deletion for remote sync.
    func deleteItem(_ item: ItemModel) async

    /// Processes any pending queue entries (called on connectivity restore).
    func resumeSync() async

    /// Resets a permanently-failed item and re-queues it for sync.
    func retryItem(_ item: ItemModel) async
}
