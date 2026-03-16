/*
 MeasureCanonicalizerTests.swift
 Created: 16.03.2026

 Purpose: Unit-Tests für MeasureCanonicalizer.canonicalize()

 CHANGELOG:
 - 16.03.2026: FAM-72 – Initial. Verifiziert Defense-in-Depth-Normalisierung im Repository-Layer.
               Tests basieren auf tatsächlichem Verhalten von Measure.fromExternal():
               Normalisierung von Groß-/Kleinschreibung und Whitespace – keine Synonym-Übersetzung.
*/

import XCTest
@testable import Famlist

final class MeasureCanonicalizerTests: XCTestCase {

    // MARK: - Idempotenz

    /// Bereits kanonische Werte bleiben unverändert.
    func test_canonicalize_alreadyCanonical_unchanged() {
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("kg"), "kg")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("g"), "g")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("l"), "l")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("ml"), "ml")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("piece"), "piece")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("can"), "can")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("bottle"), "bottle")
    }

    // MARK: - Groß-/Kleinschreibung

    /// Großbuchstaben werden auf die kanonische Kleinschreibung normalisiert.
    func test_canonicalize_uppercaseInput_normalized() {
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("KG"), "kg")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("ML"), "ml")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("G"), "g")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("L"), "l")
    }

    // MARK: - Whitespace-Trimming

    /// Führende und nachfolgende Leerzeichen werden entfernt.
    func test_canonicalize_trimmingWhitespace() {
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("  kg  "), "kg")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize(" g "), "g")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("\tml\t"), "ml")
    }

    // MARK: - Leer / Whitespace-only

    /// Leere Strings bleiben leer.
    func test_canonicalize_empty_returnsEmpty() {
        XCTAssertEqual(MeasureCanonicalizer.canonicalize(""), "")
    }

    /// Whitespace-only Strings werden als leer behandelt.
    func test_canonicalize_whitespaceOnly_returnsEmpty() {
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("   "), "")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("\t"), "")
    }

    // MARK: - Defense-in-Depth: Unbekannte Werte

    /// Unbekannte Strings die kein gültiger Measure-rawValue sind, fallen auf "piece" zurück.
    /// Dokumentiert das tatsächliche Verhalten von Measure.fromExternal() (rawValue ?? .piece).
    func test_canonicalize_unknownValue_fallsToPiece() {
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("Kilogramm"), "piece")
        XCTAssertEqual(MeasureCanonicalizer.canonicalize("unknown_unit"), "piece")
    }

    // MARK: - Defense-in-Depth: Direktaufruf ohne ViewModel

    /// Simuliert einen direkten Repository-Aufruf (z.B. aus SyncEngine) mit
    /// Groß-/Kleinschreibung – ohne ViewModel-Vorverarbeitung.
    /// Das Repository normalisiert "KG" → "kg" unabhängig vom Caller.
    func test_canonicalize_caseVariant_normalizedWithoutViewModel() {
        let rawFromSyncEngine = "KG"
        let result = MeasureCanonicalizer.canonicalize(rawFromSyncEngine)
        XCTAssertEqual(result, "kg", "Repository-Layer muss 'KG' → 'kg' normalisieren ohne ViewModel")
    }
}
