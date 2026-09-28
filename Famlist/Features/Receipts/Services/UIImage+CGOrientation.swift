/*
 UIImage+CGOrientation.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Übersetzt die Ausrichtung eines UIImage in die Schreibweise von Vision und Core Image.

 🔰 Notes for Beginners:
 - Ein Kamerafoto ist intern oft quer gespeichert und trägt nur den Vermerk „um 90° drehen“.
   Vision und Core Image brauchen diesen Vermerk als `CGImagePropertyOrientation`.
 - Genutzt von der Texterkennung und vom Zuschnitt der Bons.

 📝 Last Change:
 - Aus ReceiptTextRecognizer herausgelöst, weil der Bon-Zuschnitt sie ebenfalls braucht.
 ------------------------------------------------------------------------
 */

import UIKit

extension UIImage {
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
