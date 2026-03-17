/*
 BackoffCalculatorTests.swift
 FamlistTests
 Created on: 16.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for BackoffCalculator (FAM-74).

 🛠 Includes:
 - Base delay progression (1s → 2s → 4s → 8s → 16s → 32s → cap 60s)
 - Max-delay ceiling
 - Jitter bounds (±20 %)
 - hasExceededMaxRetries threshold
 - Custom configuration

 📝 Last Change:
 - FAM-74: Initial creation.
 ------------------------------------------------------------------------
*/

import XCTest
@testable import Famlist

@MainActor
final class BackoffCalculatorTests: XCTestCase {

    // MARK: - Base Delay Progression

    func test_baseDelay_attempt0_returnsBase() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.baseDelay(for: 0), 1.0, accuracy: 0.001,
                       "First failure delay must equal base (1 s)")
    }

    func test_baseDelay_attempt1_doubles() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.baseDelay(for: 1), 2.0, accuracy: 0.001)
    }

    func test_baseDelay_attempt2_quadruples() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.baseDelay(for: 2), 4.0, accuracy: 0.001)
    }

    func test_baseDelay_attempt3_is8s() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.baseDelay(for: 3), 8.0, accuracy: 0.001)
    }

    func test_baseDelay_attempt4_is16s() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.baseDelay(for: 4), 16.0, accuracy: 0.001)
    }

    func test_baseDelay_attempt5_is32s() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.baseDelay(for: 5), 32.0, accuracy: 0.001)
    }

    // MARK: - Max Delay Cap

    func test_baseDelay_cappedAtMaxDelay() {
        let sut = BackoffCalculator.default
        // attempt 6 would be 64 s uncapped — must be capped at 60 s
        XCTAssertEqual(sut.baseDelay(for: 6), 60.0, accuracy: 0.001,
                       "Delay must not exceed maxDelay (60 s)")
    }

    func test_baseDelay_highAttempt_neverExceedsMax() {
        let sut = BackoffCalculator.default
        for attempt in 7...20 {
            XCTAssertLessThanOrEqual(sut.baseDelay(for: attempt), sut.maxDelay,
                                     "attempt \(attempt) must not exceed maxDelay")
        }
    }

    // MARK: - Jitter Bounds

    func test_delay_withJitter_staysWithin20PercentBounds() {
        let sut = BackoffCalculator.default
        // Run multiple times to catch outliers
        for attempt in 0...5 {
            let base = sut.baseDelay(for: attempt)
            let lower = base * 0.80
            let upper = base * 1.20
            for _ in 0..<50 {
                let d = sut.delay(for: attempt)
                XCTAssertGreaterThanOrEqual(d, lower,
                    "delay(\(attempt)) \(d) below lower bound \(lower)")
                XCTAssertLessThanOrEqual(d, upper,
                    "delay(\(attempt)) \(d) above upper bound \(upper)")
            }
        }
    }

    func test_delay_isNonNegative() {
        let sut = BackoffCalculator.default
        for attempt in 0...5 {
            for _ in 0..<20 {
                XCTAssertGreaterThanOrEqual(sut.delay(for: attempt), 0)
            }
        }
    }

    // MARK: - hasExceededMaxRetries

    func test_hasExceededMaxRetries_belowThreshold_returnsFalse() {
        let sut = BackoffCalculator.default // maxRetries = 5
        for count in 0..<5 {
            XCTAssertFalse(sut.hasExceededMaxRetries(count),
                           "retryCount \(count) must not exceed threshold")
        }
    }

    func test_hasExceededMaxRetries_atThreshold_returnsTrue() {
        let sut = BackoffCalculator.default
        XCTAssertTrue(sut.hasExceededMaxRetries(5),
                      "retryCount == maxRetries must return true")
    }

    func test_hasExceededMaxRetries_aboveThreshold_returnsTrue() {
        let sut = BackoffCalculator.default
        for count in 6...10 {
            XCTAssertTrue(sut.hasExceededMaxRetries(count))
        }
    }

    // MARK: - Custom Configuration

    func test_customConfig_baseDelayRespected() {
        let sut = BackoffCalculator(base: 2.0, maxDelay: 120.0, factor: 3.0, jitterFactor: 0.10, maxRetries: 3)
        XCTAssertEqual(sut.baseDelay(for: 0), 2.0, accuracy: 0.001)
        XCTAssertEqual(sut.baseDelay(for: 1), 6.0, accuracy: 0.001)   // 2 × 3^1
        XCTAssertEqual(sut.baseDelay(for: 2), 18.0, accuracy: 0.001)  // 2 × 3^2
    }

    func test_customConfig_maxRetriesRespected() {
        let sut = BackoffCalculator(base: 1.0, maxDelay: 60.0, factor: 2.0, jitterFactor: 0.0, maxRetries: 3)
        XCTAssertFalse(sut.hasExceededMaxRetries(2))
        XCTAssertTrue(sut.hasExceededMaxRetries(3))
    }

    // MARK: - Default Constants

    func test_defaultConstants() {
        let sut = BackoffCalculator.default
        XCTAssertEqual(sut.base, 1.0)
        XCTAssertEqual(sut.maxDelay, 60.0)
        XCTAssertEqual(sut.factor, 2.0)
        XCTAssertEqual(sut.jitterFactor, 0.20, accuracy: 0.001)
        XCTAssertEqual(sut.maxRetries, 5)
    }
}
