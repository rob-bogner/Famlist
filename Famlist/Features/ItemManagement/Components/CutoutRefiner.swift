/*
 CutoutRefiner.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Nachbessern“ (PhotoCutoutFix) hinter einer gemeinsamen Schnittstelle:
   • ab iOS 17: ganze Objekte an- und abwählen (Instanzen aus ProductCutout.Analysis)
   • ab iOS 27: pixelgenau per Antippen (IterativeCutoutRefiner, Vision GenerateIterativeSegmentationRequest)

 🔰 Notes for Beginners:
 - Punkte kommen normiert (0…1, Ursprung oben links) aus CutoutFixView.
 - `start` liefert die erste Überlagerung (volle Fotogröße), `tap` die neue oder nil (nichts geändert),
   `finish` das zugeschnittene Ergebnis für den Produktkopf.

 📝 Last Change:
 - Initial creation (iOS 27 installiert, Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import CoreImage
import UIKit

protocol CutoutRefiner: AnyObject, Sendable {
    func start() async -> UIImage?
    /// nil = nichts geändert (Hintergrund getroffen oder letztes Objekt).
    func tap(_ point: CGPoint, include: Bool) async -> UIImage?
    func reset() async -> UIImage?
    /// Gewählte Instanzen (nur iOS-17-Weg) und zugeschnittenes Bild.
    func finish() async -> (IndexSet?, UIImage?)
}

/// iOS 17: ganze Objekte (Instanzen) an- und abwählen.
final class InstanceCutoutRefiner: CutoutRefiner, @unchecked Sendable {
    private let analysis: ProductCutout.Analysis
    private var selection: IndexSet

    init(analysis: ProductCutout.Analysis, selection: IndexSet) {
        self.analysis = analysis
        self.selection = selection.isEmpty ? analysis.primary : selection
    }

    func start() async -> UIImage? { await analysis.renderInBackground(selection, cropped: false) }

    func tap(_ point: CGPoint, include: Bool) async -> UIImage? {
        guard let id = analysis.instance(at: point) else { return nil }
        var next = selection
        if include { next.insert(id) } else { next.remove(id) }
        guard !next.isEmpty, next != selection else { return nil }
        selection = next
        return await analysis.renderInBackground(next, cropped: false)
    }

    func reset() async -> UIImage? {
        selection = analysis.primary
        return await analysis.renderInBackground(selection, cropped: false)
    }

    func finish() async -> (IndexSet?, UIImage?) {
        (selection, await analysis.renderInBackground(selection, cropped: true))
    }
}

/// Bildhilfen für freigestellte Bilder (Schwerpunkt, Zuschnitt auf den sichtbaren Bereich).
enum CutoutImageMath {
    static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Schwerpunkt der sichtbaren Pixel (0…1, Ursprung oben links); nil bei leerem Bild.
    static func alphaCentroid(_ image: UIImage) -> CGPoint? {
        guard let (alpha, side) = alphaGrid(image) else { return nil }
        var sx = 0.0, sy = 0.0, n = 0.0
        for y in 0..<side { for x in 0..<side where alpha[y * side + x] > 128 { sx += Double(x); sy += Double(y); n += 1 } }
        guard n > 0 else { return nil }
        return CGPoint(x: (sx / n + 0.5) / Double(side), y: (sy / n + 0.5) / Double(side))
    }

    /// Auf den sichtbaren Bereich zuschneiden, mit durchsichtigem Rand (wie ProductCutout.withMargin).
    static func croppedToContent(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage, let (alpha, side) = alphaGrid(image) else { return nil }
        var minX = side, minY = side, maxX = -1, maxY = -1
        for y in 0..<side { for x in 0..<side where alpha[y * side + x] > 16 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX >= minX, maxY >= minY else { return nil }
        let sx = CGFloat(cg.width) / CGFloat(side), sy = CGFloat(cg.height) / CGFloat(side)
        let rect = CGRect(x: CGFloat(max(minX - 1, 0)) * sx, y: CGFloat(max(minY - 1, 0)) * sy,
                          width: CGFloat(min(maxX + 2, side) - max(minX - 1, 0)) * sx,
                          height: CGFloat(min(maxY + 2, side) - max(minY - 1, 0)) * sy).integral
        guard let part = cg.cropping(to: rect) else { return nil }
        return ProductCutout.withMargin(UIImage(cgImage: part, scale: 1, orientation: .up))
    }

    /// Alpha-Werte auf einem 128er-Raster (Zeilen von oben).
    private static func alphaGrid(_ image: UIImage) -> ([UInt8], Int)? {
        guard let cg = image.cgImage else { return nil }
        let side = 128
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard ok else { return nil }
        // CGContext-Speicher beginnt mit der obersten Zeile.
        return ((0..<(side * side)).map { pixels[$0 * 4 + 3] }, side)
    }
}
