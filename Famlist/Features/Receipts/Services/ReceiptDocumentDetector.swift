/*
 ReceiptDocumentDetector.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sucht in einem Foto die vier Ecken des Kassenzettels (Vision, VNDetectDocumentSegmentationRequest, ab iOS 15).

 🔰 Notes for Beginners:
 - Vision liefert die Ecken relativ zum Bild mit Ursprung unten links. `ReceiptQuad` rechnet mit Ursprung
   oben links, deshalb wird y hier umgedreht.
 - Das Bild wird vorher aufrecht gestellt (`oriented`), damit die Ecken zum sichtbaren Foto passen –
   Kamerafotos sind intern oft quer gespeichert.
 - Findet Vision nichts Glaubwürdiges, kommt nil zurück; das Foto bleibt dann unverändert.
 - Im Simulator liefert das Erkennungsmodell unbrauchbare Ecken (gleicher Streifen bei jedem Bild,
   Sicherheit bis 0,97; geprüft 28.09.2026). Dort ist die Erkennung deshalb aus: Das Foto bleibt unverändert.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import CoreImage
import UIKit
import Vision

enum ReceiptDocumentDetector {
    /// Mindest-Sicherheit eines Treffers. Ohne Dokument meldet Vision trotzdem ein Viereck über das
    /// ganze Bild, dann aber mit Sicherheit 0 (auf dem Mac gemessen 28.09.2026; ein klarer Bon: 0,99).
    static let minimumConfidence: Float = 0.5

    /// Aufrecht gestelltes Bild mit Ursprung (0, 0); Grundlage für Erkennung und Zuschnitt.
    static func upright(_ image: UIImage) -> CIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let oriented = CIImage(cgImage: cgImage).oriented(image.cgOrientation)
        return oriented.transformed(by: CGAffineTransform(translationX: -oriented.extent.minX,
                                                          y: -oriented.extent.minY))
    }

    /// Ecken des Bons im aufrechten Bild; nil, wenn kein glaubwürdiger Bon gefunden wurde.
    static func detect(in image: CIImage) -> ReceiptQuad? {
        run(VNImageRequestHandler(ciImage: image, options: [:]))
    }

    /// Live-Erkennung auf einem Kamerabild. Die Ecken gelten im Koordinatensystem des Kamerasensors
    /// (quer, Ursprung oben links) – genau das erwartet `AVCaptureVideoPreviewLayer.layerPointConverted`.
    static func detect(in pixelBuffer: CVPixelBuffer) -> ReceiptQuad? {
        run(VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:]))
    }

    private static func run(_ handler: VNImageRequestHandler) -> ReceiptQuad? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let request = VNDetectDocumentSegmentationRequest()
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              observation.confidence >= minimumConfidence else { return nil }
        let quad = ReceiptQuad(topLeft: flipped(observation.topLeft),
                               topRight: flipped(observation.topRight),
                               bottomRight: flipped(observation.bottomRight),
                               bottomLeft: flipped(observation.bottomLeft))
        return quad.isPlausible ? quad : nil
        #endif
    }

    /// Vision: Ursprung unten links → ReceiptQuad: Ursprung oben links.
    static func flipped(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: 1 - point.y) }
}
