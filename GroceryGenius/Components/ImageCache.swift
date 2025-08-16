// ImageCache.swift
// Einfache In-Memory Cache für Base64-dekodierte UIImages
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 500 }

    func image(fromBase64 base64: String?) -> UIImage? {
        guard let base64, !base64.isEmpty else { return nil }
        if let cached = cache.object(forKey: base64 as NSString) { return cached }
        guard let data = Data(base64Encoded: base64), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: base64 as NSString)
        return img
    }
}
