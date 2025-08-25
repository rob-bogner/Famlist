// MARK: - ImageCache.swift

/*
 File: ImageCache.swift
 Project: GroceryGenius
 Created: 27.04.2025 (approx.)
 Last Updated: 17.08.2025

 Overview:
 Lightweight in‑memory cache for Base64-decoded UIImages to avoid repeated decode cost when cells re-render.

 Responsibilities / Includes:
 - NSCache<String, UIImage> wrapper
 - Base64 decode on cache miss
 - Count limit tuning

 Design Notes:
 - NSCache auto-purges under memory pressure
 - Key uses full Base64 string (trade-off: longer key vs. zero collisions); could hash later
 - Thread-safe since NSCache is internally synchronized

 Possible Enhancements:
 - Add sizeLimit based on total memory
 - Add disk persistence layer
 - Provide async prefetching API
*/
import SwiftUI
import ImageIO

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, CGImage>()
    private init() { cache.countLimit = 500 }

    /// Returns a cached SwiftUI Image constructed from a decoded CGImage if available.
    /// Falls back to nil when the base64 is empty or decoding fails.
    func swiftUIImage(fromBase64 base64: String?) -> Image? {
        guard let cg = cgImage(fromBase64: base64) else { return nil }
        return Image(decorative: cg, scale: 1, orientation: .up)
    }

    /// Backwards-compatible helper that returns a UIImage created from the cached CGImage.
    /// Note: This avoids importing UIKit here by relying on SwiftUI's availability of UIImage.
    func image(fromBase64 base64: String?) -> UIImage? {
        guard let cg = cgImage(fromBase64: base64) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Core decoding
    private func cgImage(fromBase64 base64: String?) -> CGImage? {
        guard let base64, !base64.isEmpty else { return nil }
        if let cached = cache.object(forKey: base64 as NSString) { return cached }
        guard let data = Data(base64Encoded: base64) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceShouldCache: true]
        guard let src = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, options as CFDictionary) else { return nil }
        cache.setObject(cg, forKey: base64 as NSString)
        return cg
    }
}
