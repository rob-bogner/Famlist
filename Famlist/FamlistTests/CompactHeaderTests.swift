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

    /// „Kopf ganz eingeklappt“ gilt ab der Übergangsstrecke – Grundlage für Tab-Tipps im Nachlauf (CoastingTabsCatcher).
    @MainActor
    func test_scrollState_headerCompact_fromCollapseRangeOn() {
        let scroll = ListScrollState()
        scroll.update(offset: 500)
        XCTAssertFalse(scroll.isHeaderCompact, "ohne gemessene Übergangsstrecke nie eingeklappt")

        scroll.collapseRange = CollapsingListHeader.collapseRange(heroHeight: 128)   // 52 + 18 + 88 = 158
        scroll.update(offset: 157)
        XCTAssertFalse(scroll.isHeaderCompact)
        scroll.update(offset: 158)
        XCTAssertTrue(scroll.isHeaderCompact)
        scroll.update(offset: 20)
        XCTAssertFalse(scroll.isHeaderCompact, "beim Zurückscrollen wieder aufgeklappt")
    }

    /// Titelzeile 44 + Abstand 18 + Leiste 40 + Abstand 18.
    func test_compactTabsTop() {
        XCTAssertEqual(CollapsingListHeader.compactTabsTop, 120)
    }
}
