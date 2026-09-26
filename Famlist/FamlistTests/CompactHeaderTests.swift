/*
 CompactHeaderTests.swift
 FamlistTests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den fließenden Listenkopf (CollapsingListHeader): Fortschritt und Übergangsstrecke.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class CompactHeaderTests: XCTestCase {
    func test_progress_isClampedAndLinear() {
        XCTAssertEqual(CollapsingListHeader.progress(offset: -40, range: 158), 0)      // Pull-to-Refresh
        XCTAssertEqual(CollapsingListHeader.progress(offset: 0, range: 158), 0)
        XCTAssertEqual(CollapsingListHeader.progress(offset: 79, range: 158), 0.5, accuracy: 0.0001)
        XCTAssertEqual(CollapsingListHeader.progress(offset: 400, range: 158), 1)
    }

    /// Kopf schrumpft genau um den Scroll-Weg: Suche 52 + Abstand 18 + (Karte − Leiste 40).
    func test_collapseRange_matchesHeightDifference() {
        XCTAssertEqual(CollapsingListHeader.collapseRange(heroHeight: 128), 52 + 18 + 88)
        XCTAssertEqual(CollapsingListHeader.collapseRange(heroHeight: 30), 70)          // nie negativ
    }
}
