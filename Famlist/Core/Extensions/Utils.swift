/*
 Utils.swift

 GroceryGenius
 Created on: 20.07.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Collection of lightweight utility helpers shared across the app (image <-> Base64 conversion).

 🛠 Includes:
 - Deprecated imageToBase64() wrapper (use UIImage+Utils extension instead)

 🔰 Notes for Beginners:
 - JPEG compression is set to 0.8 as a balance of size and quality.
 - Use UIImage.toBase64() extension for new code (centralized in UIImage+Utils)
 - For Base64 -> UIImage decoding, use ImageCache.shared.image(fromBase64:) which provides caching.

 📝 Last Change:
 - Deprecated imageToBase64() in favor of centralized UIImage.toBase64() extension.
 ------------------------------------------------------------------------
 */

import Foundation // Provides Data for Base64 conversions
import UIKit // Provides UIImage used by the helpers

/// Encodes an optional UIImage into a Base64 string (JPEG, quality 0.8).
/// - Parameter image: Source image.
/// - Returns: Base64 string or nil if image is nil / encoding fails.
@available(*, deprecated, message: "Use UIImage.toBase64() extension instead")
func imageToBase64(_ image: UIImage?) -> String? {
    return image?.toBase64() // Delegate to centralized extension
}
