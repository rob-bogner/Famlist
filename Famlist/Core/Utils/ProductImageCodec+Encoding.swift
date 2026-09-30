/*
 ProductImageCodec+Encoding.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Verkleinern und Kodieren von Produktfotos (UIKit, nur iOS-Target): JPEG, freigestellte als HEIC mit Transparenz.

 📝 Last Change:
 - Freigestellte Fotos (transparent) als HEIC/PNG statt JPEG (30.09.2026).
 - Aus ProductImageCodec.swift ausgelagert, damit der Rest für watchOS kompiliert.
 ------------------------------------------------------------------------
 */

import UIKit

extension ProductImageCodec {
    /// Längste Kante in Pixeln.
    static let maxPixelSize: CGFloat = 600
    static let jpegQuality: CGFloat = 0.72

    /// Verkleinertes Bild als Base64 (lokale Kopie in SwiftData): JPEG, freigestellte Fotos als HEIC mit
    /// Transparenz (PNG, falls HEIC nicht geht) – sonst ginge der transparente Hintergrund verloren.
    static func encode(_ image: UIImage) -> String? {
        let data = ProductCutout.isCutout(image) ? cutoutData(image) : jpegData(image)
        return data?.base64EncodedString()
    }

    /// Freigestelltes Foto: verkleinert, Transparenz bleibt erhalten.
    static func cutoutData(_ image: UIImage) -> Data? {
        let size = image.size
        let longest = max(size.width * image.scale, size.height * image.scale)
        guard longest > 0 else { return nil }
        let factor = min(1, maxPixelSize / longest)
        let target = CGSize(width: (size.width * image.scale * factor).rounded(),
                            height: (size.height * image.scale * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.heicData() ?? resized.pngData()
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
}
