// MARK: - Utils.swift

/*
 File: Utils.swift
 Project: GroceryGenius
 Created: 20.07.2025
 Last Updated: 17.08.2025

 Overview:
 Collection of lightweight utility helpers shared across the app (image <-> Base64 conversion).

 Responsibilities / Includes:
 - UIImage -> Base64 encoding helper
 - Base64 -> UIImage decoding helper

 Design Notes:
 - Compression quality fixed (0.8) as a pragmatic balance between size & quality
 - Helpers kept free functions for simple usage without dependency injection overhead

 Possible Enhancements:
 - Add caching layer for frequent conversions (currently handled separately by ImageCache)
 - Support PNG preservation for transparency if needed
*/

import Foundation
import UIKit

/// Encodes an optional UIImage into a Base64 string with size-aware compression.
/// Downscales to maxDimension and adjusts JPEG quality to keep payload under maxBytes.
/// - Parameters:
///   - image: Source image.
///   - maxBytes: Target maximum encoded size (default ~600 KB to stay below Firestore 1 MB document limits including other fields).
///   - maxDimension: Longest side after downscaling (points assumed = pixels for JPEG here).
///   - minQuality: Lower bound for JPEG quality when searching.
/// - Returns: Base64 string or nil if image is nil / encoding fails.
func imageToBase64(_ image: UIImage?, maxBytes: Int = 600_000, maxDimension: CGFloat = 1024, minQuality: CGFloat = 0.5) -> String? {
    guard let image else { return nil }

    // 1) Downscale if needed (preserve aspect)
    let resized: UIImage = {
        let w = image.size.width, h = image.size.height
        let longest = max(w, h)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: max(1, w * scale), height: max(1, h * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // work in pixel space for predictable size
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }()

    // 2) Binary search JPEG quality to fit under maxBytes
    var low: CGFloat = minQuality
    var high: CGFloat = 0.9
    var bestData: Data? = nil

    for _ in 0..<6 { // 6 iterations are enough to converge
        let q = (low + high) / 2
        guard let data = resized.jpegData(compressionQuality: q) else { break }
        if data.count <= maxBytes { bestData = data; low = q } else { high = q }
    }

    let finalData = bestData ?? resized.jpegData(compressionQuality: minQuality)
    guard let finalData else { return nil }
    return finalData.base64EncodedString()
}

/// Decodes an optional Base64 string into UIImage.
/// - Parameter base64: Source Base64 string.
/// - Returns: UIImage instance or nil if decoding fails.
func base64ToImage(_ base64: String?) -> UIImage? {
    guard let base64, let data = Data(base64Encoded: base64) else { return nil }
    return UIImage(data: data)
}
