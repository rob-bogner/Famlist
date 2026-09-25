/*
 ReceiptTextRecognizer.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Texterkennung auf Bon-Fotos mit Vision (VNRecognizeTextRequest, de-DE, genau).
   Liefert Textzeilen von oben nach unten – über alle Aufnahmen eines langen Bons hinweg.

 🔰 Notes for Beginners:
 - Vision liefert einzelne Textblöcke mit Position. Artikeltext (links) und Preis (rechts) sind oft zwei
   Blöcke. Blöcke, deren Mitte auf gleicher Höhe liegt, werden zu EINER Zeile verbunden (links → rechts).
 - Sprachkorrektur ist aus: Bons sind voller Abkürzungen („KOKOSM.“), die die Korrektur „verbessern“ würde.
 - Läuft im Hintergrund (Task.detached), damit die Oberfläche nicht hängt.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import UIKit
import Vision

enum ReceiptTextRecognizer {
    struct Fragment {
        let text: String
        let box: CGRect          // Vision-Koordinaten: 0…1, Ursprung unten links
    }

    /// Erkennt alle Seiten nacheinander und hängt ihre Zeilen aneinander.
    static func recognizeLines(in images: [UIImage]) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            var lines: [String] = []
            for image in images {
                lines += (try? recognize(image)) ?? []
            }
            return lines
        }.value
    }

    private static func recognize(_ image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE"]
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation, options: [:])
        try handler.perform([request])
        let fragments = (request.results ?? []).compactMap { obs -> Fragment? in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return Fragment(text: text, box: obs.boundingBox)
        }
        return groupIntoLines(fragments)
    }

    /// Verbindet Blöcke mit überlappender Höhe zu Zeilen (oben → unten, links → rechts).
    static func groupIntoLines(_ fragments: [Fragment]) -> [String] {
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Fragment]] = []
        for f in sorted {
            if let last = rows.last, let ref = last.first,
               abs(ref.box.midY - f.box.midY) < max(ref.box.height, f.box.height) * 0.5 {
                rows[rows.count - 1].append(f)
            } else {
                rows.append([f])
            }
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "   ")
        }
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
