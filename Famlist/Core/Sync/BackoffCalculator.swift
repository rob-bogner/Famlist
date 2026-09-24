/*
 BackoffCalculator.swift
 Famlist
 Created on: 16.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Pure, testable exponential backoff calculator (FAM-74).
 - Decoupled from SyncEngine so retry parameters are configurable and
   the calculation can be unit-tested without infrastructure dependencies.

 🛠 Includes:
 - baseDelay(for:) — deterministic delay without jitter (testable)
 - delay(for:)     — production delay with ±jitter applied
 - hasExceededMaxRetries(_:) — gate check after recording a failure

 🔰 Notes for Beginners:
 - `attempt` is zero-based: attempt 0 = first failure → base delay.
 - Jitter prevents thundering-herd when multiple devices retry simultaneously.

 📝 Last Change:
 - FAM-74: Initial implementation replacing inline SyncEngine.exponentialBackoff().
 ------------------------------------------------------------------------
*/

import Foundation

/// Calculates exponential backoff delays with optional jitter.
///
/// Default configuration: base 1 s, max 60 s, factor ×2, jitter ±20 %, max 5 retries.
struct BackoffCalculator {

    // MARK: - Configuration

    /// Base delay for the first retry attempt (seconds).
    let base: TimeInterval

    /// Hard ceiling on any single delay (seconds).
    let maxDelay: TimeInterval

    /// Multiplicative factor applied per attempt.
    let factor: Double

    /// Fraction of the computed delay added/subtracted as random jitter (0.20 = ±20 %).
    let jitterFactor: Double

    /// Maximum number of retry attempts before an operation is marked as permanently failed.
    let maxRetries: Int

    // MARK: - Default

    /// Production-ready defaults: 1 s / 60 s / ×2 / ±20 % / 5 retries.
    static let `default` = BackoffCalculator(
        base: 1.0,
        maxDelay: 60.0,
        factor: 2.0,
        jitterFactor: 0.20,
        maxRetries: 5
    )

    // MARK: - Calculation

    /// Returns the raw delay for a given attempt without jitter.
    ///
    /// Suitable for logging and unit tests where determinism is required.
    /// - Parameter attempt: Zero-based attempt index (0 = first failure).
    func baseDelay(for attempt: Int) -> TimeInterval {
        let raw = base * pow(factor, Double(attempt))
        return min(raw, maxDelay)
    }

    /// Returns the jitter-adjusted delay for production use.
    ///
    /// Applies a random offset in `[-jitterFactor, +jitterFactor]` to the base delay
    /// to spread retries across clients and avoid thundering-herd scenarios.
    /// - Parameter attempt: Zero-based attempt index (0 = first failure).
    func delay(for attempt: Int) -> TimeInterval {
        let raw = baseDelay(for: attempt)
        let jitter = Double.random(in: -jitterFactor...jitterFactor)
        return max(0, raw * (1.0 + jitter))
    }

    /// Returns `true` when the retry count (after the latest increment) has
    /// reached or exceeded `maxRetries`, meaning no further automatic retries
    /// should be scheduled.
    /// - Parameter retryCountAfterFailure: `retryCount` value after incrementing for the current failure.
    func hasExceededMaxRetries(_ retryCountAfterFailure: Int) -> Bool {
        retryCountAfterFailure >= maxRetries
    }
}
