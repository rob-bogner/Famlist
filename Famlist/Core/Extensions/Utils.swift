/*
 Utils.swift

 GroceryGenius
 Created on: 20.07.2025
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Collection of lightweight utility helpers shared across the app (image <-> Base64 conversion).

 🛠 Includes:
 - UIImage -> Base64 encoding helper
 - Base64 -> UIImage decoding helper

 🔰 Notes for Beginners:
 - JPEG compression is set to 0.8 as a balance of size and quality.
 - Free functions are straightforward to call from anywhere without creating objects.

 📝 Last Change:
 - Standardized header to the required format and clarified doc comments. No functional changes.
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

/// Decodes an optional Base64 string into UIImage.
/// - Parameter base64: Source Base64 string.
/// - Returns: UIImage instance or nil if decoding fails.
func base64ToImage(_ base64: String?) -> UIImage? {
    guard let base64, let data = Data(base64Encoded: base64) else { return nil } // Decode Base64 into bytes
    return UIImage(data: data) // Construct UIImage from bytes
}
