/*
 QuantityMergeTests.swift
 FamlistTests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für das Zusammenführen von Mengen bei doppelten Artikeln (Regel B: umrechnen und addieren).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class QuantityMergeTests: XCTestCase {

    private func combine(_ e: Double, _ em: String, _ a: Double, _ am: String) -> (Double, String) {
        let r = QuantityMerge.combine(existing: (e, em), added: (a, am))
        return (r.units, r.measure)
    }

    func test_sameMeasure_adds() {
        XCTAssertTrue(combine(1, "kg", 0.5, "kg") == (1.5, "kg"))
        XCTAssertTrue(combine(0.1, "l", 0.2, "l") == (0.3, "l"))           // kein 0,30000000000000004
    }

    func test_addedWithoutMeasure_addsToExisting() {
        XCTAssertTrue(combine(1, "pack", 1, "") == (2, "pack"))
    }

    func test_convertible_resultInAddedMeasure() {
        XCTAssertTrue(combine(500, "g", 1, "kg") == (1.5, "kg"))
        XCTAssertTrue(combine(1, "kg", 500, "g") == (1500, "g"))
        XCTAssertTrue(combine(250, "ml", 1, "l") == (1.25, "l"))
        XCTAssertTrue(combine(50, "cm", 1, "m") == (1.5, "m"))
    }

    /// 5 g + 1 kg wären 1,005 kg (3 Nachkommastellen) → in Gramm.
    func test_convertible_fallsBackToOtherMeasure_whenNotExact() {
        XCTAssertTrue(combine(5, "g", 1, "kg") == (1005, "g"))
    }

    /// 6000 g + 5 kg = 11000 g (über 9999) → in Kilogramm.
    func test_convertible_fallsBackToLargerMeasure_whenAboveMaximum() {
        XCTAssertTrue(combine(5, "kg", 6000, "g") == (11, "kg"))
    }

    func test_incompatible_addedWins() {
        XCTAssertTrue(combine(3, "piece", 500, "g") == (500, "g"))
        XCTAssertTrue(combine(500, "g", 1, "l") == (1, "l"))
    }

    func test_sameMeasure_clampsToMaximum() {
        XCTAssertTrue(combine(9000, "g", 2000, "g") == (9999, "g"))
    }
}
