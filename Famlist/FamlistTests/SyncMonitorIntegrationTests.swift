/*
 SyncMonitorIntegrationTests.swift
 FamlistTests
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests for SyncMonitor metric tracking (FAM-38).
 - Verifies that startOperation/endOperation, failure recording,
   and queue-depth updates behave correctly.

 📝 Last Change:
 - FAM-38: Initial creation.
 ------------------------------------------------------------------------
*/

import XCTest
@testable import Famlist

@MainActor
final class SyncMonitorIntegrationTests: XCTestCase {

    // MARK: - totalOperations

    func test_processOperation_success_incrementsTotalOperations() {
        let sut = SyncMonitor()
        XCTAssertEqual(sut.totalOperations, 0)

        let id = sut.startOperation()
        sut.endOperation(id, success: true, latency: 0.1)

        XCTAssertEqual(sut.totalOperations, 1)
    }

    func test_processOperation_multipleSuccesses_incrementsCorrectly() {
        let sut = SyncMonitor()

        for _ in 0..<3 {
            let id = sut.startOperation()
            sut.endOperation(id, success: true, latency: 0.05)
        }

        XCTAssertEqual(sut.totalOperations, 3)
        XCTAssertEqual(sut.failedOperations, 0)
    }

    // MARK: - failedOperations

    func test_processOperation_failure_recordsFailure() {
        let sut = SyncMonitor()

        let id = sut.startOperation()
        sut.endOperation(id, success: false, latency: 0.1)

        XCTAssertEqual(sut.totalOperations, 1)
        XCTAssertEqual(sut.failedOperations, 1)
    }

    func test_processOperation_mixedResults_countsCorrectly() {
        let sut = SyncMonitor()

        let id1 = sut.startOperation()
        sut.endOperation(id1, success: true, latency: 0.05)

        let id2 = sut.startOperation()
        sut.endOperation(id2, success: false, latency: 0.05)

        let id3 = sut.startOperation()
        sut.endOperation(id3, success: true, latency: 0.05)

        XCTAssertEqual(sut.totalOperations, 3)
        XCTAssertEqual(sut.failedOperations, 1)
    }

    // MARK: - queueDepth

    func test_updatePendingCount_updatesQueueDepth() {
        let sut = SyncMonitor()
        XCTAssertEqual(sut.queueDepth, 0)

        sut.updateQueueDepth(5)

        XCTAssertEqual(sut.queueDepth, 5)
    }

    func test_updateQueueDepth_toZero_reflects() {
        let sut = SyncMonitor()
        sut.updateQueueDepth(3)
        sut.updateQueueDepth(0)

        XCTAssertEqual(sut.queueDepth, 0)
    }

    // MARK: - averageSyncLatency

    func test_averageSyncLatency_isUpdated_afterOperation() {
        let sut = SyncMonitor()

        let id = sut.startOperation()
        sut.endOperation(id, success: true, latency: 0.05) // 50 ms

        XCTAssertGreaterThan(sut.averageSyncLatency, 0,
                             "averageSyncLatency must be > 0 after recording a 50 ms operation")
    }

    func test_averageSyncLatency_approximatesInput() {
        let sut = SyncMonitor()

        let id = sut.startOperation()
        sut.endOperation(id, success: true, latency: 0.1) // 100 ms

        // averageSyncLatency is stored in ms: 0.1 s × 1000 = 100 ms
        XCTAssertEqual(sut.averageSyncLatency, 100.0, accuracy: 0.001)
    }

    // MARK: - successRate

    func test_successRate_allSuccess_is100() {
        let sut = SyncMonitor()

        let id = sut.startOperation()
        sut.endOperation(id, success: true, latency: 0.01)

        XCTAssertEqual(sut.successRate, 100.0, accuracy: 0.001)
    }

    func test_successRate_noOperations_is100() {
        let sut = SyncMonitor()
        XCTAssertEqual(sut.successRate, 100.0)
    }

    // MARK: - reset

    func test_reset_clearsAllMetrics() {
        let sut = SyncMonitor()
        let id = sut.startOperation()
        sut.endOperation(id, success: false, latency: 0.2)
        sut.updateQueueDepth(7)
        sut.recordConflict()

        sut.reset()

        XCTAssertEqual(sut.totalOperations, 0)
        XCTAssertEqual(sut.failedOperations, 0)
        XCTAssertEqual(sut.averageSyncLatency, 0)
        XCTAssertEqual(sut.queueDepth, 0)
        XCTAssertEqual(sut.conflictCount, 0)
    }
}
