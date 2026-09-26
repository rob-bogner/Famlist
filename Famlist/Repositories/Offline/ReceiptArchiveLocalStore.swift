/*
 ReceiptArchiveLocalStore.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lokaler Teil des Kassenzettel-Archivs: zuletzt geladene Einträge, Warteschlange (Anlegen/Löschen)
   und die Fotos als JPEG-Dateien.

 🔰 Notes for Beginners:
 - Noch nicht hochgeladene Fotos liegen in Application Support (iOS löscht sie nicht von selbst).
   Nach dem Hochladen wandern sie in den Ordner Caches: Dort darf iOS bei Platzmangel aufräumen,
   die Fotos werden dann einfach neu vom Server geladen.
 - Dateipfad = Pfad im Bucket (`<list_id>/<receipt_id>/<n>.jpg`) unterhalb des jeweiligen Ordners.
 - Beim Abmelden wird alles gelöscht (`clear()`), damit nichts beim nächsten Konto landet.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ReceiptArchiveLocalStore {
    enum Operation: Codable, Equatable {
        case create(ArchivedReceipt)
        case delete(ArchivedReceipt)

        var receipt: ArchivedReceipt {
            switch self {
            case .create(let receipt), .delete(let receipt): return receipt
            }
        }
    }

    /// Wartender Auftrag mit Zahl der Fehlversuche (ohne Netzfehler).
    struct Pending: Codable, Equatable {
        var operation: Operation
        var failures = 0
    }

    private let cacheURL: URL
    private let outboxURL: URL
    let pendingPhotos: URL
    let cachedPhotos: URL
    private(set) var cache: [ArchivedReceipt]
    private(set) var outbox: [Pending]

    init(directory: URL = ReceiptArchiveLocalStore.defaultDirectory,
         photoCache: URL = ReceiptArchiveLocalStore.defaultPhotoCache) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("receipts_cache.json")
        outboxURL = directory.appendingPathComponent("receipts_outbox.json")
        pendingPhotos = directory.appendingPathComponent("photos", isDirectory: true)
        cachedPhotos = photoCache
        cache = LocalJSONFile.read([ArchivedReceipt].self, from: cacheURL) ?? []
        outbox = LocalJSONFile.read([Pending].self, from: outboxURL) ?? []
    }

    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ReceiptArchive", isDirectory: true)
    }

    nonisolated static var defaultPhotoCache: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ReceiptArchivePhotos", isDirectory: true)
    }

    // MARK: - Einträge und Warteschlange

    func setCache(_ receipts: [ArchivedReceipt]) {
        cache = receipts
        LocalJSONFile.write(receipts, to: cacheURL)
    }

    func addToCache(_ receipt: ArchivedReceipt) {
        setCache([receipt] + cache.filter { $0.id != receipt.id })
    }

    func removeFromCache(id: UUID) {
        setCache(cache.filter { $0.id != id })
    }

    func enqueue(_ operation: Operation) {
        outbox.append(Pending(operation: operation))
        saveOutbox()
    }

    /// Entfernt einen Auftrag (per Inhalt, nicht per Position: während des Sendens kann sich die Liste ändern).
    func remove(_ operation: Operation) {
        outbox.removeAll { $0.operation == operation }
        saveOutbox()
    }

    func recordFailure(_ operation: Operation) {
        guard let i = outbox.firstIndex(where: { $0.operation == operation }) else { return }
        outbox[i].failures += 1
        saveOutbox()
    }

    private func saveOutbox() {
        LocalJSONFile.write(outbox, to: outboxURL)
    }

    // MARK: - Fotos

    func writePendingPhoto(_ data: Data, path: String) throws {
        let url = pendingPhotos.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Foto aus der Warteschlange, sonst aus dem Cache.
    func photo(path: String) -> Data? {
        (try? Data(contentsOf: pendingPhotos.appendingPathComponent(path)))
            ?? (try? Data(contentsOf: cachedPhotos.appendingPathComponent(path)))
    }

    func cachePhoto(_ data: Data, path: String) {
        let url = cachedPhotos.appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Nach dem Hochladen: Fotos aus der Warteschlange in den Cache verschieben.
    func movePendingPhotosToCache(paths: [String]) {
        for path in paths {
            let source = pendingPhotos.appendingPathComponent(path)
            guard let data = try? Data(contentsOf: source) else { continue }
            cachePhoto(data, path: path)
            try? FileManager.default.removeItem(at: source)
        }
    }

    func removePhotos(paths: [String]) {
        for path in paths {
            try? FileManager.default.removeItem(at: pendingPhotos.appendingPathComponent(path))
            try? FileManager.default.removeItem(at: cachedPhotos.appendingPathComponent(path))
        }
    }

    /// Abmelden: Einträge, Warteschlange und alle Fotos löschen.
    func clear() {
        cache = []
        outbox = []
        [cacheURL, outboxURL, pendingPhotos, cachedPhotos].forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
