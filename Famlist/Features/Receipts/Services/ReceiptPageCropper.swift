/*
 ReceiptPageCropper.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schneidet den Kassenzettel aus einem Foto und zieht ihn gerade (Core Image, CIPerspectiveCorrection).
   Ergebnis: ein Bild, als wäre der Bon genau von oben fotografiert.

 🔰 Notes for Beginners:
 - `autoCrop` sucht die Ecken selbst (ReceiptDocumentDetector). Findet es keinen Bon, bleibt das Foto,
   wie es ist – lieber ein Foto mit Tisch als ein falsch abgeschnittener Bon.
 - `crop(_:to:)` nimmt vorgegebene Ecken, z. B. später aus „Ecken korrigieren“.
 - Die Farben bleiben wie fotografiert (kein Aufhellen, Entscheidung Robert 28.09.2026).
 - Läuft im Hintergrund (Task.detached): Erkennung und Zuschnitt eines 12-MP-Fotos dauern spürbar.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum ReceiptPageCropper {
    struct Result: Sendable {
        /// Gefundene Ecken; nil, wenn kein Bon erkannt wurde.
        let quad: ReceiptQuad?
        /// Zuschnitt oder – ohne Treffer – das unveränderte Foto.
        let image: UIImage
    }

    /// Ein gemeinsamer Kontext: Ihn für jedes Foto neu anzulegen, kostet Zeit und Speicher.
    private static let context = CIContext()

    /// Sucht den Bon, schneidet ihn aus und zieht ihn gerade.
    static func autoCrop(_ image: UIImage) async -> Result {
        await Task.detached(priority: .userInitiated) {
            guard let upright = ReceiptDocumentDetector.upright(image),
                  let quad = ReceiptDocumentDetector.detect(in: upright),
                  let cropped = render(upright, quad: quad) else { return Result(quad: nil, image: image) }
            return Result(quad: quad, image: cropped)
        }.value
    }

    /// Zuschnitt mit vorgegebenen Ecken; nil, wenn das Bild nicht lesbar ist.
    static func crop(_ image: UIImage, to quad: ReceiptQuad) -> UIImage? {
        guard let upright = ReceiptDocumentDetector.upright(image) else { return nil }
        return render(upright, quad: quad)
    }

    /// Wie `crop(_:to:)`, aber im Hintergrund (für „Ecken anpassen“ – ein 12-MP-Foto dauert spürbar).
    static func cropInBackground(_ image: UIImage, to quad: ReceiptQuad) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { crop(image, to: quad) }.value
    }

    private static func render(_ upright: CIImage, quad: ReceiptQuad) -> UIImage? {
        let corners = quad.pixelCorners(in: upright.extent.size)
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = upright
        filter.topLeft = corners.topLeft
        filter.topRight = corners.topRight
        filter.bottomRight = corners.bottomRight
        filter.bottomLeft = corners.bottomLeft
        guard let output = filter.outputImage, !output.extent.isEmpty, !output.extent.isInfinite,
              let cgImage = context.createCGImage(output, from: output.extent.integral) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}

