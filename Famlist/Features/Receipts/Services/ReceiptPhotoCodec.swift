/*
 ReceiptPhotoCodec.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Macht aus einer Bon-Aufnahme ein JPEG für das Archiv: lange Kante höchstens 2000 px, Qualität 0,7.

 🔰 Notes for Beginners:
 - Der Bucket `receipt-images` nimmt höchstens 1,5 MB je Foto an (Migration 021). Ist das JPEG größer,
   wird die Qualität schrittweise gesenkt; ein Bon bleibt dabei lesbar.
 - Kleinere Bilder werden nicht vergrößert.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import UIKit

enum ReceiptPhotoCodec {
    static let bucket = "receipt-images"
    static let maxLongEdge: CGFloat = 2000
    static let quality: CGFloat = 0.7
    static let maxBytes = 1_572_864

    /// JPEG-Daten für den Upload; nil, wenn das Bild nicht kodierbar ist.
    static func jpeg(from image: UIImage) -> Data? {
        let scaled = downscaled(image)
        var q = quality
        while q >= 0.3 {
            guard let data = scaled.jpegData(compressionQuality: q) else { return nil }
            if data.count <= maxBytes { return data }
            q -= 0.1
        }
        return nil
    }

    /// Verkleinert so, dass die lange Kante höchstens `maxLongEdge` Pixel hat (Maßstab 1 = echte Pixel).
    static func downscaled(_ image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longEdge = max(pixelSize.width, pixelSize.height)
        let factor = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        guard target.width > 0, target.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
