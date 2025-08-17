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

/// Encodes an optional UIImage into a Base64 string (JPEG, quality 0.8).
/// - Parameter image: Source image.
/// - Returns: Base64 string or nil if image is nil / encoding fails.
func imageToBase64(_ image: UIImage?) -> String? {
    guard let image, let data = image.jpegData(compressionQuality: 0.8) else { return nil }
    return data.base64EncodedString()
}

/// Decodes an optional Base64 string into UIImage.
/// - Parameter base64: Source Base64 string.
/// - Returns: UIImage instance or nil if decoding fails.
func base64ToImage(_ base64: String?) -> UIImage? {
    guard let base64, let data = Data(base64Encoded: base64) else { return nil }
    return UIImage(data: data)
}
