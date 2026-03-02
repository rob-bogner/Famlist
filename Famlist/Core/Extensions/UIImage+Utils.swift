/*
 UIImage+Utils.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Centralized UIImage utility extensions for Base64 conversion and caching

 🛠 Includes:
 - toBase64(): Convert UIImage to Base64 string
 - fromBase64(): Create UIImage from Base64 string
 - Consistent compression quality across the app

 🔰 Notes for Beginners:
 - These extensions eliminate scattered image conversion code
 - Quality set to 0.8 balances file size and visual quality
 - Nil-safe operations prevent crashes on invalid data

 📝 Last Change:
 - Initial creation to centralize image handling logic
 ------------------------------------------------------------------------
 */

import UIKit // For UIImage and image data operations

extension UIImage {
    
    // MARK: - Base64 Conversion
    
    /// Converts the image to a Base64-encoded string
    /// - Parameter compressionQuality: JPEG quality (0.0 to 1.0), defaults to 0.8
    /// - Returns: Base64 string or nil if conversion fails
    func toBase64(compressionQuality: CGFloat = 0.8) -> String? {
        guard let imageData = self.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
    
    /// Creates a UIImage from a Base64-encoded string
    /// - Parameter base64String: The Base64 string to decode
    /// - Returns: UIImage or nil if decoding fails
    static func fromBase64(_ base64String: String?) -> UIImage? {
        guard let base64String = base64String else { return nil }
        guard let imageData = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: imageData)
    }
    
    /// Creates a UIImage from optional Base64 string (convenience wrapper)
    /// - Parameter base64String: Optional Base64 string
    /// - Returns: UIImage or nil
    static func fromBase64Optional(_ base64String: String?) -> UIImage? {
        return fromBase64(base64String)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension UIImage {
    /// Creates a solid color image for testing/previews
    /// - Parameters:
    ///   - color: Fill color
    ///   - size: Image dimensions
    /// - Returns: UIImage filled with the specified color
    static func fromColor(_ color: UIColor, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
#endif
