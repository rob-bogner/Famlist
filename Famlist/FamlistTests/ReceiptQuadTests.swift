/*
 ReceiptQuadTests.swift
 FamlistTests

 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für die Ecken eines Bons: Fläche, Plausibilität, Umrechnung in Pixel.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptQuadTests: XCTestCase {
    private func quad(_ tl: (CGFloat, CGFloat), _ tr: (CGFloat, CGFloat),
                      _ br: (CGFloat, CGFloat), _ bl: (CGFloat, CGFloat)) -> ReceiptQuad {
        ReceiptQuad(topLeft: CGPoint(x: tl.0, y: tl.1), topRight: CGPoint(x: tr.0, y: tr.1),
                    bottomRight: CGPoint(x: br.0, y: br.1), bottomLeft: CGPoint(x: bl.0, y: bl.1))
    }

    func test_area_wholeImageIsOne() {
        XCTAssertEqual(quad((0, 0), (1, 0), (1, 1), (0, 1)).area, 1, accuracy: 0.0001)
        XCTAssertEqual(quad((0.25, 0.25), (0.75, 0.25), (0.75, 0.75), (0.25, 0.75)).area, 0.25, accuracy: 0.0001)
    }

    func test_isPlausible_rejectsTinyArea() {
        // 0,2 × 0,3 = 6 % – unter der Grenze von 8 %
        XCTAssertFalse(quad((0.4, 0.4), (0.6, 0.4), (0.6, 0.7), (0.4, 0.7)).isPlausible)
        XCTAssertTrue(quad((0.3, 0.1), (0.7, 0.12), (0.72, 0.9), (0.28, 0.88)).isPlausible)
    }

    /// Überkreuzte Ecken (Schleife statt Viereck) sind kein Bon.
    func test_isPlausible_rejectsCrossedCorners() {
        XCTAssertFalse(quad((0, 0), (1, 1), (1, 0), (0, 1)).isPlausible)
    }

    /// Core Image zählt y von unten: Die obere linke Ecke landet oben im Pixelbild.
    func test_pixelCorners_flipsYAxis() {
        let corners = quad((0.1, 0.2), (0.9, 0.2), (0.9, 0.8), (0.1, 0.8)).pixelCorners(in: CGSize(width: 1000, height: 2000))
        XCTAssertEqual(corners.topLeft.x, 100, accuracy: 0.001)
        XCTAssertEqual(corners.topLeft.y, 1600, accuracy: 0.001)
        XCTAssertEqual(corners.bottomRight.x, 900, accuracy: 0.001)
        XCTAssertEqual(corners.bottomRight.y, 400, accuracy: 0.001)
    }
}
