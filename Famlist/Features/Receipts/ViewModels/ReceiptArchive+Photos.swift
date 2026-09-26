/*
 ReceiptArchive+Photos.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fotos des Kassenzettel-Archivs laden: lokal (Warteschlange oder Cache), sonst vom Server.

 🔰 Notes for Beginners:
 - Erst die Datei im App-Ordner, dann Supabase Storage; Geladenes wird als Datei zwischengespeichert
   (Ordner Caches) und dekodiert im Speicher-Cache `images` gehalten.
 - Vorschaubilder (Archiv-Zeile) werden klein dekodiert, das Detail bekommt die volle Größe.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import UIKit

extension ReceiptArchive {
    /// JPEG-Daten eines Fotos; nil, wenn es weder lokal noch auf dem Server erreichbar ist.
    func photoData(path: String) async -> Data? {
        if let local = store.photo(path: path) { return local }
        guard let repository, let data = try? await repository.downloadPhoto(path: path) else { return nil }
        store.cachePhoto(data, path: path)
        return data
    }

    /// Bild eines Fotos. `maxPixel` = lange Kante in Pixeln (Vorschau), nil = volle Größe (Detail).
    func image(path: String, maxPixel: Int? = nil) async -> UIImage? {
        let key = "\(path)#\(maxPixel ?? 0)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let data = await photoData(path: path) else { return nil }
        let decoded = await Task.detached(priority: .userInitiated) {
            maxPixel.map { ReceiptPhotoCodec.thumbnail(from: data, maxPixel: $0) } ?? UIImage(data: data)
        }.value
        if let decoded { images.setObject(decoded, forKey: key) }
        return decoded
    }
}
