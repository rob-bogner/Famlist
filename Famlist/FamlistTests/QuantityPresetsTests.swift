/*
 QuantityPresetsTests.swift
 FamlistTests

 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für die Mengen-Eingabe: Schrittweite je Einheit, Einrasten, Grenzen, Schnellwahl.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class QuantityPresetsTests: XCTestCase {
    func test_step_dependsOnMeasure() {
        XCTAssertEqual(QuantityPresets.step(for: "g"), 50)
        XCTAssertEqual(QuantityPresets.step(for: "ml"), 50)
        XCTAssertEqual(QuantityPresets.step(for: "kg"), 1)
        XCTAssertEqual(QuantityPresets.step(for: "pack"), 1)
    }

    func test_next_snapsToStep_andClamps() {
        XCTAssertEqual(QuantityPresets.next(1, up: true, step: 50), 50)
        XCTAssertEqual(QuantityPresets.next(120, up: true, step: 50), 150)
        XCTAssertEqual(QuantityPresets.next(120, up: false, step: 50), 100)
        XCTAssertEqual(QuantityPresets.next(50, up: false, step: 50), 1)          // nie unter 1
        XCTAssertEqual(QuantityPresets.next(9999, up: true, step: 50), 9999)
        XCTAssertEqual(QuantityPresets.next(1, up: false, step: 1), 1)
        XCTAssertEqual(QuantityPresets.next(3, up: true, step: 1), 4)
    }

    /// Kommazahlen: ± rastet auf die Schrittweite ein; unter 1 senkt „−“ nicht weiter ab.
    func test_next_withDecimals() {
        XCTAssertEqual(QuantityPresets.next(1.5, up: true, step: 1), 2)
        XCTAssertEqual(QuantityPresets.next(1.5, up: false, step: 1), 1)
        XCTAssertEqual(QuantityPresets.next(0.5, up: true, step: 1), 1)
        XCTAssertEqual(QuantityPresets.next(0.5, up: false, step: 1), 0.5)
        XCTAssertEqual(QuantityPresets.next(125.5, up: true, step: 50), 150)
    }

    func test_validation_allowsDecimals() {
        XCTAssertNil(ItemInputValidator.validateUnits("1,5"))
        XCTAssertNil(ItemInputValidator.validateUnits("0.25"))
        XCTAssertNotNil(ItemInputValidator.validateUnits("0"))
        XCTAssertNotNil(ItemInputValidator.validateUnits("abc"))
    }

    func test_gramPresets_includeKilogram() {
        let presets = QuantityPresets.presets(for: "g")
        XCTAssertEqual(presets.map(\.label), ["100 g", "250 g", "500 g", "1 kg"])
        XCTAssertEqual(presets.last?.measure, "kg")
        XCTAssertEqual(presets.last?.units, 1)
    }

    func test_validation_allowsGramAmounts() {
        XCTAssertNil(ItemInputValidator.validateUnits("500"))
        XCTAssertNil(ItemInputValidator.validateUnits("9999"))
        XCTAssertNotNil(ItemInputValidator.validateUnits("10000"))
    }
}
