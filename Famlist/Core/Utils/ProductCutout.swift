/*
 ProductCutout.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Freistellen von Artikelfotos mit Vision (ab iOS 17, nur auf dem Gerät): Motiv finden, Hintergrund
   entfernen, auf das Motiv zuschneiden. Design: PhotoCutoutScan / PhotoCutoutDone / PhotoCutoutFix.

 🔰 Notes for Beginners:
 - VNGenerateForegroundInstanceMaskRequest liefert eine Maske mit durchnummerierten Motiven (Instanzen).
   Wir nehmen das größte, möglichst mittige Motiv; beim „Nachbessern“ kommen per Antippen weitere dazu
   oder fallen weg.
 - Läuft nicht im Simulator (Vision-Fehler) → dann bleibt einfach das Originalfoto.
 - Das Ergebnis ist ein Bild mit transparentem Hintergrund; `isCutout` erkennt solche Bilder später wieder
   (transparente Ecken), damit Kopf und Kachel sie auf dem neutralen Verlauf zeigen statt randlos.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026: Foto automatisch ausschneiden).
 ------------------------------------------------------------------------
 */

import CoreImage
import UIKit
import Vision

enum ProductCutout {
    /// Ergebnis der Analyse eines Fotos. Hält Handler und Maske, damit „Nachbessern“ ohne neue Analyse
    /// andere Motive wählen kann.
    final class Analysis: @unchecked Sendable {
        let source: UIImage
        let handler: VNImageRequestHandler
        let observation: VNInstanceMaskObservation
        /// Vom Algorithmus gewähltes Hauptmotiv.
        let primary: IndexSet
        /// Maske als Zahlen je Pixel (0 = Hintergrund, 1… = Motiv), für das Antippen.
        private let labels: [UInt8]
        private let maskWidth: Int
        private let maskHeight: Int

        fileprivate init(source: UIImage, handler: VNImageRequestHandler, observation: VNInstanceMaskObservation,
                         primary: IndexSet, labels: [UInt8], maskWidth: Int, maskHeight: Int) {
            self.source = source
            self.handler = handler
            self.observation = observation
            self.primary = primary
            self.labels = labels
            self.maskWidth = maskWidth
            self.maskHeight = maskHeight
        }

        /// Motiv an einer Stelle (0…1, Ursprung oben links) oder nil für Hintergrund.
        func instance(at point: CGPoint) -> Int? {
            guard maskWidth > 0, maskHeight > 0 else { return nil }
            let x = min(max(Int(point.x * CGFloat(maskWidth)), 0), maskWidth - 1)
            let y = min(max(Int(point.y * CGFloat(maskHeight)), 0), maskHeight - 1)
            let label = Int(labels[y * maskWidth + x])
            return label == 0 ? nil : label
        }

        /// Freigestelltes Bild der gewählten Motive. `cropped` = auf das Motiv zugeschnitten (für den Kopf),
        /// sonst in voller Fotogröße (für die Überlagerung beim Nachbessern).
        func render(_ instances: IndexSet, cropped: Bool) -> UIImage? {
            guard !instances.isEmpty,
                  let buffer = try? observation.generateMaskedImage(ofInstances: instances, from: handler,
                                                                    croppedToInstancesExtent: cropped) else { return nil }
            let ci = CIImage(cvPixelBuffer: buffer)
            guard let cg = ProductCutout.context.createCGImage(ci, from: ci.extent) else { return nil }
            return UIImage(cgImage: cg, scale: 1, orientation: .up)
        }

        /// Wie `render`, aber im Hintergrund (Nachbessern: jedes Antippen erzeugt ein neues Bild).
        func renderInBackground(_ instances: IndexSet, cropped: Bool) async -> UIImage? {
            await Task.detached(priority: .userInitiated) { self.render(instances, cropped: cropped) }.value
        }
    }

    fileprivate static let context = CIContext(options: [.useSoftwareRenderer: false])
    /// Längste Kante für die Analyse (schneller, reicht für 600-px-Artikelbilder).
    private static let analysisMaxPixel: CGFloat = 1400

    /// Freistellen im Hintergrund. nil = kein Motiv gefunden oder Vision nicht verfügbar (Simulator).
    static func analyze(_ image: UIImage) async -> Analysis? {
        await Task.detached(priority: .userInitiated) { () -> Analysis? in
            guard let upright = normalized(image), let cg = upright.cgImage else { return nil }
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            let request = VNGenerateForegroundInstanceMaskRequest()
            do { try handler.perform([request]) } catch {
                logVoid(params: (action: "productCutout.failed", error: (error as NSError).localizedDescription))
                return nil
            }
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let (labels, w, h) = readLabels(observation.instanceMask)
            let primary = pickPrimary(labels: labels, width: w, height: h, all: observation.allInstances)
            return Analysis(source: upright, handler: handler, observation: observation, primary: primary,
                            labels: labels, maskWidth: w, maskHeight: h)
        }.value
    }

    /// true, wenn das Bild einen transparenten Hintergrund hat (freigestellt).
    static func isCutout(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        switch cg.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return false }
        let corners = [0, side - 1, side * (side - 1), side * side - 1]
        return corners.filter { pixels[$0 * 4 + 3] < 16 }.count >= 3
    }

    // MARK: - Intern

    /// Aufrecht und verkleinert zeichnen (Vision soll kein gedrehtes Foto bekommen).
    private static func normalized(_ image: UIImage) -> UIImage? {
        let size = image.size
        let longest = max(size.width, size.height) * image.scale
        guard longest > 0 else { return nil }
        let factor = min(1, analysisMaxPixel / longest)
        let target = CGSize(width: (size.width * image.scale * factor).rounded(),
                            height: (size.height * image.scale * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func readLabels(_ buffer: CVPixelBuffer) -> ([UInt8], Int, Int) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return ([], 0, 0) }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w { out[y * w + x] = ptr[y * row + x] }
        }
        return (out, w, h)
    }

    /// Größtes Motiv, mittige Motive bevorzugt (Fläche × (1 − 0,6 × Abstand zur Mitte)).
    private static func pickPrimary(labels: [UInt8], width: Int, height: Int, all: IndexSet) -> IndexSet {
        guard width > 0, height > 0 else { return IndexSet(all.prefix(1)) }
        var area = [Int: Int](), sumX = [Int: Int](), sumY = [Int: Int]()
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let label = Int(labels[y * width + x])
                guard label != 0 else { continue }
                area[label, default: 0] += 1
                sumX[label, default: 0] += x
                sumY[label, default: 0] += y
            }
        }
        let best = area.max { a, b in score(a, sumX, sumY, width, height) < score(b, sumX, sumY, width, height) }
        return best.map { IndexSet(integer: $0.key) } ?? IndexSet(all.prefix(1))
    }

    private static func score(_ entry: (key: Int, value: Int), _ sx: [Int: Int], _ sy: [Int: Int], _ w: Int, _ h: Int) -> Double {
        let n = Double(max(entry.value, 1))
        let cx = Double(sx[entry.key] ?? 0) / n / Double(w) - 0.5
        let cy = Double(sy[entry.key] ?? 0) / n / Double(h) - 0.5
        let distance = min((cx * cx + cy * cy).squareRoot() / 0.7071, 1)
        return n * (1 - 0.6 * distance)
    }
}
