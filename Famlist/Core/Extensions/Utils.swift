/*
 Utils.swift

 GroceryGenius
 Created on: 20.07.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Collection of lightweight utility helpers shared across the app (image <-> Base64 conversion).

 🛠 Includes:
 - UIImage -> Base64 encoding helper

 🔰 Notes for Beginners:
 - JPEG compression is set to 0.8 as a balance of size and quality.
 - Free functions are straightforward to call from anywhere without creating objects.
 - For Base64 -> UIImage decoding, use ImageCache.shared.image(fromBase64:) which provides caching.

 📝 Last Change:
 - Removed unused base64ToImage() function (dead code; ImageCache provides same functionality with caching).
 ------------------------------------------------------------------------
 */

import Foundation // Provides Data for Base64 conversions
import UIKit // Provides UIImage used by the helpers

/// Encodes an optional UIImage into a Base64 string (JPEG, quality 0.8).
/// - Parameter image: Source image.
/// - Returns: Base64 string or nil if image is nil / encoding fails.
func imageToBase64(_ image: UIImage?) -> String? {
    guard let image, let data = image.jpegData(compressionQuality: 0.8) else { return nil } // Convert to JPEG data; bail if conversion fails
    return data.base64EncodedString() // Convert bytes to Base64 string
}
