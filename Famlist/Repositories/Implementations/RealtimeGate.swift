/*
 RealtimeGate.swift
 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Encapsulates the three Realtime suppression flags that previously
   lived as loose properties in SupabaseItemsRepository.

 🛠 Includes:
 - Pessimistic lock (isSuppressing)
 - Optimistic event counter (expectedEvents)
 - Stale-lock detection (lockStartTime / staleLockThreshold)

 🔰 Notes for Beginners:
 - Extracted from SupabaseItemsRepository as part of FAM-67.
 - All mutations are @MainActor-isolated; share the same actor as
   SupabaseItemsRepository so no additional synchronisation is needed.

 📝 Last Change:
 - Initial extraction (FAM-67).
 ------------------------------------------------------------------------
*/

import Foundation

/// Controls Realtime-fetch suppression during batch operations.
///
/// Encapsulates the three state flags that previously lived directly in
/// `SupabaseItemsRepository`, isolating the lock lifecycle in one place
/// and making the suppression logic independently testable.
@MainActor
final class RealtimeGate {

    // MARK: - State

    /// True while a batch operation is in progress and Realtime events should be suppressed.
    private(set) var isSuppressing: Bool = false

    /// Number of Realtime events still expected before the lock releases automatically.
    private(set) var expectedEvents: Int = 0

    /// Timestamp when the current lock was acquired (used for stale-lock detection).
    private(set) var lockStartTime: Date?

    // MARK: - Configuration

    /// Maximum allowed lock duration before it is considered stale and auto-cleared.
    let staleLockThreshold: TimeInterval = 60  // 1 minute

    /// Fallback timeout for the event-counter strategy.
    let eventCounterTimeout: TimeInterval = 5.0 // 5 seconds

    // MARK: - Lock Management

    /// Acquires the suppression lock and initialises the event counter.
    /// - Parameter count: Number of Realtime events expected during this batch.
    func acquireLock(expecting count: Int) {
        isSuppressing = true
        expectedEvents = count
        lockStartTime = Date()
    }

    /// Explicitly releases the suppression lock and clears all state.
    func releaseLock() {
        isSuppressing = false
        expectedEvents = 0
        lockStartTime = nil
    }

    /// Decrements the event counter; releases the lock automatically when all events arrive.
    /// - Parameter listId: Used only for diagnostic logging.
    /// - Returns: `true` if the lock was released by this call.
    @discardableResult
    func decrementEventCounter(for listId: UUID) -> Bool {
        guard isSuppressing, expectedEvents > 0 else { return false }
        expectedEvents -= 1
        logVoid(params: (
            action: "realtimeGate.decrement",
            remaining: expectedEvents,
            listId: listId
        ))
        guard expectedEvents == 0 else { return false }
        releaseLock()
        logVoid(params: (
            action: "realtimeGate.lockReleased",
            reason: "allEventsReceived",
            listId: listId
        ))
        return true
    }

    /// Checks for a stale lock (older than `staleLockThreshold`) and clears it if found.
    /// - Returns: `true` if a stale lock was cleared.
    @discardableResult
    func checkAndClearStaleLock() -> Bool {
        guard isSuppressing, let start = lockStartTime else { return false }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > staleLockThreshold else { return false }
        releaseLock()
        logVoid(params: (
            action: "realtimeGate.staleLockCleared",
            elapsed: elapsed
        ))
        return true
    }
}
