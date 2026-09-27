/*
 QuantityFormatTests.swift
 FamlistTests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für Mengen mit Nachkommastellen: lesen, anzeigen, runden, Eingabe säubern, Server-Zeile lesen.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class QuantityFormatTests: XCTestCase {

    func test_parse_acceptsCommaAndDot() {
        XCTAssertEqual(QuantityFormat.parse("1,5"), 1.5)
        XCTAssertEqual(QuantityFormat.parse("1.5"), 1.5)
        XCTAssertEqual(QuantityFormat.parse(" 500 "), 500)
        XCTAssertEqual(QuantityFormat.parse("1,234"), 1.23)
        XCTAssertNil(QuantityFormat.parse(""))
        XCTAssertNil(QuantityFormat.parse("abc"))
    }

    func test_format_germanWithoutTrailingZeros() {
        XCTAssertEqual(QuantityFormat.format(1.5), "1,5")
        XCTAssertEqual(QuantityFormat.format(2), "2")
        XCTAssertEqual(QuantityFormat.format(0.25), "0,25")
        XCTAssertEqual(QuantityFormat.format(1500), "1500")          // kein Tausenderpunkt
    }

    func test_normalized_removesFloatingPointNoise() {
        XCTAssertEqual(QuantityFormat.normalized(0.1 + 0.2), 0.3)
        XCTAssertEqual(QuantityFormat.normalized(1.005 * 1000) / 1000, 1.005, accuracy: 0.001)
    }

    func test_sanitizeInput_limitsDigitsAndSeparator() {
        XCTAssertEqual(QuantityFormat.sanitizeInput("12345"), "1234")
        XCTAssertEqual(QuantityFormat.sanitizeInput("1,234"), "1,23")
        XCTAssertEqual(QuantityFormat.sanitizeInput("1.5"), "1,5")
        XCTAssertEqual(QuantityFormat.sanitizeInput(",5"), "0,5")
        XCTAssertEqual(QuantityFormat.sanitizeInput("1,2,3"), "1,23")
        XCTAssertEqual(QuantityFormat.sanitizeInput("1,"), "1,")
    }

    func test_quantityText_showsDecimalWithUnit() {
        XCTAssertEqual(ItemModel(name: "Hack", units: 1.5, measure: "kg").quantityText.hasPrefix("1,5 "), true)
        XCTAssertEqual(ItemModel(name: "Eier", units: 2).quantityText, "2")
    }

    /// Server liefert seit Migration 025 numeric: 1.5 und ganze Zahlen (2) müssen sich lesen lassen.
    func test_supabaseRow_decodesDecimalAndIntegerUnits() throws {
        for (json, expected) in [("1.5", 1.5), ("2", 2.0)] {
            let data = Data("""
            {"id":"\(UUID().uuidString)","list_id":"\(UUID().uuidString)","name":"Hack","units":\(json),
             "measure":"kg","price":0,"isChecked":false}
            """.utf8)
            let row = try JSONDecoder().decode(SupabaseItemRow.self, from: data)
            XCTAssertEqual(row.units, expected)
        }
    }
}
