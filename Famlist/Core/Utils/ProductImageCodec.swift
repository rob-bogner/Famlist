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
 - Verkleinern/Kodieren (UIKit) nach ProductImageCodec+Encoding.swift; dieser Teil kompiliert auch für watchOS (26.09.2026).
 - Initial creation (Audit 25.09.2026, Fotos in Storage).
 ------------------------------------------------------------------------
 */

import CryptoKit
import Foundation

enum ProductImageCodec {
    static let itemBucket = "item-images"
    static let catalogBucket = "catalog-images"

    /// Storage-Pfad „<Ordner>/<sha256>.jpg“ und die Rohdaten zu einem Base64-Foto.
    static func storageObject(folder: UUID, base64: String) -> (path: String, data: Data)? {
        guard let data = Data(base64Encoded: base64), !data.isEmpty else { return nil }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ("\(folder.uuidString.lowercased())/\(hash).jpg", data)
    }
}
