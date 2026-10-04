/*
 IterativeCutoutRefiner.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Nachbessern“ ab iOS 27: pixelgenau per Antippen mit Vision `GenerateIterativeSegmentationRequest`
   (WWDC26, „What's new in image understanding“). Design: PhotoCutoutFix.

 🔰 Notes for Beginners:
 - Start: die automatische Freistellung (iOS-17-Weg) als Überlagerung; ihr Schwerpunkt wird der erste
   „Samen“-Punkt. Jedes Antippen fügt einen Punkt hinzu (Hinzufügen) oder schließt ihn aus (Entfernen),
   die Maske wird neu berechnet.
 - Vision rechnet in normierten Koordinaten mit Ursprung UNTEN links → y wird umgedreht.
 - Schlägt Vision fehl, ändert sich nichts (Warn-Haptik in CutoutFixView).
 - Die API ist neu (Xcode 27). Die Namen sind am iOS-27.0-SDK geprüft: init(seedPoint:), die Anfrage ist
   eine Klasse, addIncludedPoint/addExcludedPoint werfen Fehler.

 📝 Last Change:
 - An das iOS-27.0-SDK angepasst (Build-Fehler), Anfrage je Antippen neu aufgebaut (30.09.2026).
 - Initial creation (iOS 27 installiert, Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

@available(iOS 27.0, *)
final class IterativeCutoutRefiner: CutoutRefiner, @unchecked Sendable {
    /// Ein angetippter Punkt: Motiv hinzufügen oder ausschließen.
    private struct Mark: Sendable {
        let point: NormalizedPoint
        let include: Bool
    }

    private let analysis: ProductCutout.Analysis
    private var seed: CGPoint?
    /// Bestätigte Punkte (Vision hat mit ihnen gerechnet). Die Anfrage ist eine Klasse und wird bei jedem
    /// Antippen neu aufgebaut, damit ein fehlgeschlagener Punkt nicht in ihr hängen bleibt.
    private var marks: [Mark] = []
    private var refined = false
    private var current: UIImage?

    init(analysis: ProductCutout.Analysis) {
        self.analysis = analysis
    }

    func start() async -> UIImage? {
        let first = await analysis.renderInBackground(analysis.primary, cropped: false)
        seed = first.flatMap(CutoutImageMath.alphaCentroid)
        current = first
        return first
    }

    func tap(_ point: CGPoint, include: Bool) async -> UIImage? {
        guard let cg = analysis.source.cgImage else { return nil }
        // Ohne Startpunkt (kein automatisches Motiv) wird der erste Tipp selbst zum Startpunkt.
        let seedPoint = Self.visionPoint(seed ?? point)
        let next = seed == nil ? marks : marks + [Mark(point: Self.visionPoint(point), include: include)]
        guard let image = await Task.detached(priority: .userInitiated, operation: { () -> UIImage? in
            do {
                let request = GenerateIterativeSegmentationRequest(seedPoint: seedPoint)
                for mark in next {
                    if mark.include { try request.addIncludedPoint(mark.point) } else { try request.addExcludedPoint(mark.point) }
                }
                guard let observation = try await ImageRequestHandler(cg).perform(request) else { return nil }
                return Self.apply(mask: CIImage(cgImage: try observation.cgImage), to: cg)
            } catch {
                logVoid(params: (action: "iterativeCutout.failed", error: (error as NSError).localizedDescription))
                return nil
            }
        }).value else { return nil }
        if seed == nil { seed = point }
        marks = next
        refined = true
        current = image
        return image
    }

    func reset() async -> UIImage? {
        marks = []
        refined = false
        return await start()
    }

    func finish() async -> (IndexSet?, UIImage?) {
        // Nie angetippt: das automatische Ergebnis unverändert übernehmen.
        guard refined, let current else { return (analysis.primary, await analysis.renderInBackground(analysis.primary, cropped: true)) }
        let cropped = await Task.detached(priority: .userInitiated) { CutoutImageMath.croppedToContent(current) }.value
        return (nil, cropped)
    }

    // MARK: - Intern

    /// Oben links (UI) → unten links (Vision).
    private static func visionPoint(_ p: CGPoint) -> NormalizedPoint {
        NormalizedPoint(x: min(max(p.x, 0), 1), y: 1 - min(max(p.y, 0), 1))
    }

    /// Maske auf Fotogröße skalieren und das Foto damit ausstanzen (Hintergrund durchsichtig).
    private static func apply(mask: CIImage, to cg: CGImage) -> UIImage? {
        let source = CIImage(cgImage: cg)
        let scaled = mask.transformed(by: CGAffineTransform(scaleX: source.extent.width / mask.extent.width,
                                                            y: source.extent.height / mask.extent.height))
        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = CIImage(color: .clear).cropped(to: source.extent)
        blend.maskImage = scaled
        guard let output = blend.outputImage,
              let out = CutoutImageMath.context.createCGImage(output, from: source.extent, format: .RGBA8,
                                                             colorSpace: CGColorSpaceCreateDeviceRGB()) else { return nil }
        return UIImage(cgImage: out, scale: 1, orientation: .up)
    }
}
