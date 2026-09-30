/*
 RemoteProductImage.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lädt ein Produktbild aus dem globalen Katalog (OpenFoodFacts-Adresse) und wandelt es in dasselbe Format
   wie ein Kamerafoto um (verkleinertes JPEG als Base64, ProductImageCodec).

 🔰 Notes for Beginners:
 - Nur https-Adressen, höchstens `maxBytes`, ohne HTTP-Cache (AppSupabaseClient.uncachedSession).
 - Gibt nil zurück, wenn etwas nicht klappt (kein Netz, kein Bild) – der Artikel bleibt dann ohne Foto.

 📝 Last Change:
 - Initial creation (Fehler 30.09.2026: Produkte aus „Weitere Produkte“ kamen ohne Bild in die Liste).
 ------------------------------------------------------------------------
 */

import UIKit

enum RemoteProductImage {
    static let maxBytes = 5_000_000

    /// Lädt das Bild und liefert es als Base64-JPEG (wie `ItemModel.imageData`).
    static func base64JPEG(from urlString: String) async -> String? {
        guard let url = allowedURL(urlString) else { return nil }
        do {
            let (data, response) = try await AppSupabaseClient.uncachedSession.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return encode(data)
        } catch {
            logVoid(params: (action: "remoteProductImage.failed", error: (error as NSError).localizedDescription))
            return nil
        }
    }

    /// Nur https mit Host; alles andere (http, file, leer) wird abgelehnt.
    static func allowedURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false else { return nil }
        return url
    }

    /// Bilddaten → verkleinertes JPEG als Base64; nil bei zu großen oder unlesbaren Daten.
    static func encode(_ data: Data) -> String? {
        guard !data.isEmpty, data.count <= maxBytes, let image = UIImage(data: data) else { return nil }
        return ProductImageCodec.encode(image)
    }
}
