/*
 SyncOrchestrator.swift
 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Serialises concurrent remote data paths: PageLoader and Realtime events.
 - Prevents Race Conditions between pagination upserts and Realtime processing.

 🛠 Includes:
 - isPageLoading flag guarding Realtime event processing during page fetch.
 - Coalescing event buffer: only one pending handler per item id (UPDATE wins, DELETE evicts).
 - Budget protection: if the buffer exceeds 200 entries, all pending events are discarded
   and an IncrementalSync is scheduled instead.

 🔰 Notes for Beginners:
 - All code is @MainActor — no true parallel execution. The `isPageLoading` flag
   ensures that Realtime handlers arriving during an async network suspension are
   buffered until the page fetch completes.

 📝 FAM-79: Initial implementation.
 ------------------------------------------------------------------------
*/

import Foundation

// MARK: - SyncOrchestrator

/// Coordinates PageLoader and Realtime event processing so they never race over SwiftData.
@MainActor
final class SyncOrchestrator {

    // MARK: - State

    /// True while a remote page fetch is in progress. Realtime handlers are buffered during this window.
    private(set) var isPageLoading = false

    /// Buffered Realtime handlers, keyed by item id string for simple last-event-wins coalescing.
    private var pendingHandlersByItemId: [String: () async -> Void] = [:]

    /// Ordered list of item ids for FIFO flushing (preserves insertion order).
    private var pendingItemIds: [String] = []

    /// Called when the buffer exceeds the budget limit; triggers an IncrementalSync fallback.
    var onBudgetExceeded: (() -> Void)?

    private let budgetLimit = 200
    private let warningLimit = 50

    // MARK: - Page Load Coordination

    /// Executes `work` while holding the page-load lock.
    /// Any Realtime handlers arriving during `work` are buffered and flushed afterwards.
    func runPageLoad<T>(_ work: () async throws -> T) async rethrows -> T {
        isPageLoading = true
        defer {
            isPageLoading = false
            Task { await self.flushPendingHandlers() }
        }
        return try await work()
    }

    // MARK: - Realtime Event Buffering

    /// Registers a Realtime handler for `itemId`.
    /// - If no page load is in flight: executes `handler` immediately.
    /// - If a page load is in flight: buffers `handler`, replacing any previous handler for `itemId`.
    /// - If the buffer exceeds `budgetLimit`: flushes by discarding all pending handlers
    ///   and notifying `onBudgetExceeded` to trigger an IncrementalSync instead.
    func enqueueOrProcess(itemId: String, handler: @escaping () async -> Void) async {
        if !isPageLoading {
            await handler()
            return
        }

        // Coalesce: last handler for same itemId wins.
        if pendingHandlersByItemId[itemId] == nil {
            pendingItemIds.append(itemId)
        }
        pendingHandlersByItemId[itemId] = handler

        if pendingHandlersByItemId.count >= budgetLimit {
            logVoid(params: (
                action: "SyncOrchestrator.budgetExceeded",
                pendingCount: pendingHandlersByItemId.count
            ))
            pendingHandlersByItemId.removeAll()
            pendingItemIds.removeAll()
            onBudgetExceeded?()
            return
        }

        if pendingHandlersByItemId.count == warningLimit {
            logVoid(params: (
                action: "SyncOrchestrator.bufferWarning",
                pendingCount: pendingHandlersByItemId.count
            ))
        }
    }

    // MARK: - Private

    /// Flushes all buffered Realtime handlers in FIFO order, then clears the buffer.
    private func flushPendingHandlers() async {
        // Snapshot and clear before iterating to avoid re-entrancy issues.
        let ids = pendingItemIds
        let handlers = pendingHandlersByItemId
        pendingItemIds.removeAll()
        pendingHandlersByItemId.removeAll()

        for itemId in ids {
            if let handler = handlers[itemId] {
                await handler()
            }
        }

        logVoid(params: (action: "SyncOrchestrator.flushed", handlerCount: ids.count))
    }
}
