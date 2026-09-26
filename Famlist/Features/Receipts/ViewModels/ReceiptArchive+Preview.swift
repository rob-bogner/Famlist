/*
 ReceiptArchive+Preview.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Archiv mit den Beispiel-Bons aus dem Design (Vorschauen, Design-Modus der UI-Tests).

 🔰 Notes for Beginners:
 - Eigener temporärer Ordner je Aufruf; nichts landet im echten App-Ordner.
 - Jedes Foto ist der gezeichnete Beispiel-Bon (ReceiptSampleBon), liegt im Foto-Cache und im Speicher-Repository.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import UIKit

extension ReceiptArchive {
    static func preview(_ samples: [ArchivedReceipt] = ArchivedReceipt.designSamples,
                        defaults: UserDefaults = UserDefaults(suiteName: "receiptArchivePreview") ?? .standard) -> ReceiptArchive {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReceiptArchivePreview-\(UUID().uuidString)", isDirectory: true)
        let store = ReceiptArchiveLocalStore(directory: root.appendingPathComponent("support"),
                                             photoCache: root.appendingPathComponent("caches"))
        store.setCache(samples)
        if let data = ReceiptSampleBon.image().jpegData(compressionQuality: 0.9) {
            samples.flatMap(\.photoPaths).forEach { store.cachePhoto(data, path: $0) }
        }
        return ReceiptArchive(repository: InMemoryReceiptsRepository(samples), store: store, defaults: defaults)
    }
}
