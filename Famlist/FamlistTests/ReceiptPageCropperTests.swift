/*
 ReceiptPageCropperTests.swift
 FamlistTests

 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den automatischen Bon-Zuschnitt mit echtem Vision: künstliches Foto mit schräg liegendem
   weißem Bon auf dunklem Tisch → Ecken finden, gerade ziehen, Ausrichtung beachten.

 🔰 Notes for Beginners:
 - Das Foto wird im Test gezeichnet (kein Bild im Bundle nötig). Ein echtes Kamerafoto ist schwieriger;
   das prüft erst der Test auf dem Gerät.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptPageCropperTests: XCTestCase {
    /// Bildgröße des künstlichen Fotos (Pixel, Hochformat).
    private let size = CGSize(width: 1500, height: 2000)
    /// Bon-Ecken in Pixeln, Ursprung oben links: leicht schräg, etwa 720 × 1450.
    private let corners = [CGPoint(x: 420, y: 280), CGPoint(x: 1120, y: 330),
                           CGPoint(x: 1090, y: 1790), CGPoint(x: 380, y: 1740)]

    /// Dunkler Tisch mit hellem, schrägem Bon und Textzeilen.
    private func photo(size: CGSize, corners: [CGPoint]) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(red: 0.23, green: 0.17, blue: 0.12, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let path = UIBezierPath()
            path.move(to: corners[0])
            corners.dropFirst().forEach { path.addLine(to: $0) }
            path.close()
            UIColor(white: 0.97, alpha: 1).setFill()
            path.fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 34, weight: .medium),
                                                        .foregroundColor: UIColor.black]
            path.addClip()
            let box = path.bounds
            for (i, y) in stride(from: box.minY + 60, to: box.maxY - 60, by: 58).enumerated() {
                ("ARTIKEL \(i)        \(i),99 A" as NSString).draw(at: CGPoint(x: box.minX + 70, y: y), withAttributes: attrs)
            }
        }.cgImage!
    }

    /// Das Erkennungsmodell liefert im Simulator unbrauchbare Ecken (geprüft 28.09.2026: gleicher Streifen
    /// bei jedem Bild, zufällige Sicherheit). Tests mit echter Erkennung laufen nur auf Gerät oder Mac.
    private func requireRealVision() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Vision-Dokumenterkennung funktioniert im Simulator nicht – Test auf dem iPhone ausführen.")
        #endif
    }

    private func assertClose(_ a: CGPoint, _ b: CGPoint, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: 0.03, "\(label).x", file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: 0.03, "\(label).y", file: file, line: line)
    }

    func test_autoCrop_findsReceiptCorners_andStraightensIt() async throws {
        try requireRealVision()
        let image = UIImage(cgImage: photo(size: size, corners: corners))
        let result = await ReceiptPageCropper.autoCrop(image)
        let quad = try XCTUnwrap(result.quad, "Vision hat den Bon nicht gefunden")
        let expected = corners.map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) }
        assertClose(quad.topLeft, expected[0], "topLeft")
        assertClose(quad.topRight, expected[1], "topRight")
        assertClose(quad.bottomRight, expected[2], "bottomRight")
        assertClose(quad.bottomLeft, expected[3], "bottomLeft")
        // Gerade gezogen: etwa 720 × 1450 → Seitenverhältnis ≈ 2
        let ratio = result.image.size.height / result.image.size.width
        XCTAssertEqual(ratio, 2.0, accuracy: 0.3)
        XCTAssertLessThan(result.image.size.width, size.width * 0.6, "Der Tisch wurde abgeschnitten")
    }

    /// Kamerafotos liegen intern quer und tragen den Vermerk „rechts drehen“. Der Zuschnitt muss
    /// den aufrechten Bon liefern (hoch statt quer).
    func test_autoCrop_respectsImageOrientation() async throws {
        try requireRealVision()
        // Pixel quer gespeichert: Bon liegt im Rohbild waagerecht. Anzeige mit .right dreht 90° im Uhrzeigersinn.
        let raw = CGSize(width: size.height, height: size.width)
        let rotated = corners.map { CGPoint(x: $0.y, y: size.width - $0.x) }
        let image = UIImage(cgImage: photo(size: raw, corners: rotated), scale: 1, orientation: .right)
        XCTAssertEqual(image.size, size, "Angezeigt wird Hochformat")
        let result = await ReceiptPageCropper.autoCrop(image)
        XCTAssertNotNil(result.quad)
        XCTAssertGreaterThan(result.image.size.height, result.image.size.width * 1.5, "Bon muss aufrecht stehen")
        XCTAssertEqual(result.image.imageOrientation, .up)
    }

    /// Ohne Bon im Bild bleibt das Foto unverändert.
    func test_autoCrop_withoutReceipt_keepsOriginal() async throws {
        try requireRealVision()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let empty = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800), format: format).image { ctx in
            UIColor(red: 0.23, green: 0.17, blue: 0.12, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
        }
        let result = await ReceiptPageCropper.autoCrop(empty)
        XCTAssertNil(result.quad)
        XCTAssertTrue(result.image === empty)
    }

    /// Bild ohne Pixeldaten (z. B. UIImage() in Tests): kein Absturz, Original zurück.
    func test_autoCrop_imageWithoutPixels_keepsOriginal() async {
        let blank = UIImage()
        let result = await ReceiptPageCropper.autoCrop(blank)
        XCTAssertNil(result.quad)
        XCTAssertTrue(result.image === blank)
    }

    /// Vorgegebene Ecken (später „Ecken korrigieren“): schneidet genau diesen Bereich aus.
    func test_crop_withGivenQuad() throws {
        let image = UIImage(cgImage: photo(size: size, corners: corners))
        let quad = ReceiptQuad(topLeft: CGPoint(x: 0.1, y: 0.1), topRight: CGPoint(x: 0.5, y: 0.1),
                               bottomRight: CGPoint(x: 0.5, y: 0.9), bottomLeft: CGPoint(x: 0.1, y: 0.9))
        let cropped = try XCTUnwrap(ReceiptPageCropper.crop(image, to: quad))
        XCTAssertEqual(cropped.size.width, 600, accuracy: 2)
        XCTAssertEqual(cropped.size.height, 1600, accuracy: 2)
    }

    /// Ecken beziehen sich auf das angezeigte (aufrechte) Bild, auch wenn die Pixel quer gespeichert sind.
    /// Ohne Beachtung der Ausrichtung käme 2000 × 750 heraus statt 1500 × 1000.
    func test_crop_withGivenQuad_respectsImageOrientation() throws {
        let raw = photo(size: CGSize(width: size.height, height: size.width), corners: corners.map { CGPoint(x: $0.y, y: $0.x) })
        let image = UIImage(cgImage: raw, scale: 1, orientation: .right)
        let topHalf = ReceiptQuad(topLeft: CGPoint(x: 0, y: 0), topRight: CGPoint(x: 1, y: 0),
                                  bottomRight: CGPoint(x: 1, y: 0.5), bottomLeft: CGPoint(x: 0, y: 0.5))
        let cropped = try XCTUnwrap(ReceiptPageCropper.crop(image, to: topHalf))
        XCTAssertEqual(cropped.size.width, 1500, accuracy: 2)
        XCTAssertEqual(cropped.size.height, 1000, accuracy: 2)
    }
}
