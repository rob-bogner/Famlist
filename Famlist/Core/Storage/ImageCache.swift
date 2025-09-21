/*
 ImageCache.swift

 GroceryGenius
 Created on: 27.04.2025 (approx.)
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lightweight in-memory cache for Base64-decoded UIImages to avoid repeated decode cost when cells re-render.

 🛠 Includes:
 - NSCache wrapper keyed by Base64 string and a convenience decode+cache method.

 🔰 Notes for Beginners:
 - NSCache auto-purges under memory pressure, making it safe for images.
 - Using the Base64 string as the key is simple but long; consider hashing if memory is a concern.

 📝 Last Change:
 - Standardized header to the required format; no functional changes.
 ------------------------------------------------------------------------
 */

import UIKit // UIKit provides UIImage and Data types used for caching.

/// Simple, shared in-memory cache for decoded images.
final class ImageCache { // Final so it isn't subclassed; single-purpose utility.
    static let shared = ImageCache() // Singleton instance used across the app.
    private let cache = NSCache<NSString, UIImage>() // NSCache automatically clears entries under memory pressure.
    private init() { cache.countLimit = 500 } // Private init enforces singleton; cap entries to avoid unbounded growth.

    /// Returns cached decoded image or decodes and stores it if absent.
    /// - Parameter base64: Optional Base64 source string.
    /// - Returns: UIImage or nil if the string is empty/decoding fails.
    func image(fromBase64 base64: String?) -> UIImage? { // Main API used by list rows to avoid repeated decoding.
        guard let base64, !base64.isEmpty else { return nil } // If input is nil/empty, there's nothing to decode or cache.
        if let cached = cache.object(forKey: base64 as NSString) { return cached } // Return cached image when available.
        guard let data = Data(base64Encoded: base64), let img = UIImage(data: data) else { return nil } // Decode from Base64 to Data, then to UIImage.
        cache.setObject(img, forKey: base64 as NSString) // Store decoded image so subsequent calls are fast.
        return img // Return the decoded image.
    }
}
