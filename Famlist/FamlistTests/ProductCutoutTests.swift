/*
 ProductCutoutTests.swift
 FamlistTests
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Erkennung freigestellter Fotos: Ein eckiges Motiv (Milchkarton) füllt seinen Zuschnitt bis in die Ecken.
   Erst der durchsichtige Rand macht es als freigestellt erkennbar – auch nach dem Speichern (HEIC, 600 px).

 📝 Last Change:
 - Initial creation (Meldung Robert 30.09.2026: Karton wurde randlos gezoomt).
 ------------------------------------------------------------------------
 */

import XCTest
import UIKit
@testable import Famlist

final class ProductCutoutTests: XCTestCase {
    /// Bild mit Alphakanal; `inset` = durchsichtiger Rand in Pixeln, `rounded` = runde Form statt Rechteck.
    private func motif(width: CGFloat, height: CGFloat, inset: CGFloat = 0, rounded: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            let rect = CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: inset, dy: inset)
            UIColor.systemBlue.setFill()
            if rounded { ctx.cgContext.fillEllipse(in: rect) } else { ctx.fill(rect) }
        }
    }

    func testRectangularMotifWithoutMarginLooksLikePhoto() {
        // Genau der gemeldete Fall: Karton füllt den Zuschnitt, alle Ecken deckend.
        XCTAssertFalse(ProductCutout.isCutout(motif(width: 300, height: 900)))
    }

    func testMarginMakesRectangularMotifACutout() {
        XCTAssertTrue(ProductCutout.isCutout(ProductCutout.withMargin(motif(width: 300, height: 900))))
        XCTAssertTrue(ProductCutout.isCutout(ProductCutout.withMargin(motif(width: 900, height: 300))))
    }

    func testMarginSizeIsThreePercentOfLongestSide() {
        let padded = ProductCutout.withMargin(motif(width: 300, height: 900))
        XCTAssertEqual(padded.size.width * padded.scale, 354)
        XCTAssertEqual(padded.size.height * padded.scale, 954)
    }

    func testRoundMotifWithoutMarginStaysACutout() {
        // Bisher gespeicherte Freisteller (Flasche) ohne Rand müssen weiter erkannt werden.
        XCTAssertTrue(ProductCutout.isCutout(motif(width: 400, height: 800, rounded: true)))
    }

    func testOpaquePhotoIsNoCutout() throws {
        let data = try XCTUnwrap(ProductImageCodec.jpegData(motif(width: 300, height: 300, inset: 40)))
        XCTAssertFalse(ProductCutout.isCutout(try XCTUnwrap(UIImage(data: data))))
    }

    func testPaddedRectangleSurvivesEncoding() throws {
        // Speichern verkleinert auf 600 px und schreibt HEIC/PNG; der Rand muss danach noch durchsichtig sein.
        let padded = ProductCutout.withMargin(motif(width: 1000, height: 1400))
        let base64 = try XCTUnwrap(ProductImageCodec.encode(padded))
        let decoded = try XCTUnwrap(UIImage(data: try XCTUnwrap(Data(base64Encoded: base64))))
        XCTAssertTrue(ProductCutout.isCutout(decoded))
    }
}
