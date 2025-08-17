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
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 500 }

    /// Returns cached decoded image or decodes and stores it if absent.
    /// - Parameter base64: Optional Base64 source string.
    /// - Returns: UIImage or nil if the string is empty/decoding fails.
    func image(fromBase64 base64: String?) -> UIImage? {
        guard let base64, !base64.isEmpty else { return nil }
        if let cached = cache.object(forKey: base64 as NSString) { return cached }
        guard let data = Data(base64Encoded: base64), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: base64 as NSString)
        return img
    }
}
