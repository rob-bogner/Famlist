/*
 DirectionalPanDecisionTests.swift
 FamlistTests
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests der Richtungsentscheidung des Wisch-Erkenners mit realistischen Finger-Verläufen
   (Wackeln beim Aufsetzen, schräge Wische, echtes Scrollen).

 🔰 Notes for Beginners:
 - Jeder Verlauf ist eine Folge aufsummierter Bewegungen (dx, dy) seit dem Aufsetzen.
   Entscheidend ist die erste Punktfolge, bei der decide(...) nicht mehr .undecided liefert.

 📝 Last Change:
 - Initial creation (mehr Toleranz beim Wischen).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class DirectionalPanDecisionTests: XCTestCase {
    private typealias D = DirectionalPanGestureRecognizer

    /// First decisive result along a finger path.
    private func outcome(_ path: [(CGFloat, CGFloat)]) -> D.Decision {
        for (dx, dy) in path {
            let decision = D.decide(dx: dx, dy: dy)
            if decision != .undecided { return decision }
        }
        return .undecided
    }

    func test_tinyWobbleBelowDecisionDistance_staysUndecided() {
        XCTAssertEqual(outcome([(1, 2), (-2, 4), (-3, 5)]), .undecided)
    }

    func test_verticalWobbleThenLeftSwipe_isHorizontal() {
        // Daumen rutscht erst 8 pt nach unten, dann nach links.
        XCTAssertEqual(outcome([(0, 3), (-1, 6), (-2, 8), (-6, 9), (-12, 10), (-30, 11)]), .horizontal)
    }

    func test_upwardWobbleThenRightSwipe_isHorizontal() {
        XCTAssertEqual(outcome([(0, -4), (1, -7), (5, -9), (11, -10), (25, -11)]), .horizontal)
    }

    func test_diagonalSwipeUpTo50Degrees_isHorizontal() {
        XCTAssertEqual(outcome([(-10, -11), (-20, -23)]), .horizontal)   // ~48°
    }

    func test_normalScroll_isVertical() {
        XCTAssertEqual(outcome([(0, -5), (-1, -10), (-2, -16), (-3, -30)]), .vertical)
    }

    func test_slightlyDiagonalScroll_isVertical() {
        XCTAssertEqual(outcome([(-2, -6), (-4, -12), (-6, -18)]), .vertical)  // ~72°
    }
}
