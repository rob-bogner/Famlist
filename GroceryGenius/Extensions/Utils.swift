/*
 Utils.swift
 GroceryGenius
 Created on: 20.07.2025
 ------------------------------------------------------------------------
 📄 File Overview:
 Diese Datei enthält wiederverwendbare Utility-Funktionen für die App, z.B. Preisformatierung und Base64-Konvertierung für Bilder.
 ------------------------------------------------------------------------
*/

import Foundation
import UIKit

/// Formatiert einen Double-Wert als Euro-Währung (z.B. 1.99 -> "€ 1,99")
func formatPrice(_ price: Double) -> String {
    return Formatting.priceText(price)
}

/// Konvertiert ein UIImage zu einem Base64-String
func imageToBase64(_ image: UIImage?) -> String? {
    guard let image = image, let data = image.jpegData(compressionQuality: 0.8) else { return nil }
    return data.base64EncodedString()
}

/// Konvertiert einen Base64-String zu UIImage
func base64ToImage(_ base64: String?) -> UIImage? {
    guard let base64 = base64, let data = Data(base64Encoded: base64) else { return nil }
    return UIImage(data: data)
}
