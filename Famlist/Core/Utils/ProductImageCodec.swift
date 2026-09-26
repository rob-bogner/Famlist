/*
 ProductImageCodec.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bereitet Produktfotos auf: verkleinern, als JPEG kodieren, Storage-Pfad aus dem Inhalt bilden.

 🔰 Notes for Beginners:
 - Vorher wurden Fotos in voller Kameraauflösung gespeichert (≈ 600 KB als Base64). Die Karte zeigt
   sie höchstens etwa 70 pt groß; 600 px an der langen Seite reichen auch für die Vollansicht auf
   einem Pro Max (3×). Ergebnis: typischerweise 30–80 KB.
 - Der Dateiname ist der SHA-256 des JPEG-Inhalts. Gleiches Foto = gleiche Datei; erneutes Hochladen
   ist harmlos (wichtig für die Warteschlange, die nach Abbrüchen wiederholt).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Fotos in Storage).
 ------------------------------------------------------------------------
 */

import CryptoKit
import Foundation
import UIKit

enum ProductImageCodec {
    /// Längste Kante in Pixeln.
    static let maxPixelSize: CGFloat = 600
    static let jpegQuality: CGFloat = 0.72
    static let itemBucket = "item-images"
    static let catalogBucket = "catalog-images"

    /// Verkleinertes JPEG als Base64 (lokale Kopie in SwiftData).
    static func encode(_ image: UIImage) -> String? {
        jpegData(image)?.base64EncodedString()
    }

    static func jpegData(_ image: UIImage) -> Data? {
        let size = image.size
        let longest = max(size.width * image.scale, size.height * image.scale)
        guard longest > 0 else { return nil }
        let factor = min(1, maxPixelSize / longest)
        let target = CGSize(width: (size.width * image.scale * factor).rounded(),
                            height: (size.height * image.scale * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    /// Storage-Pfad „<Ordner>/<sha256>.jpg“ und die Rohdaten zu einem Base64-Foto.
    static func storageObject(folder: UUID, base64: String) -> (path: String, data: Data)? {
        guard let data = Data(base64Encoded: base64), !data.isEmpty else { return nil }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ("\(folder.uuidString.lowercased())/\(hash).jpg", data)
    }
}
