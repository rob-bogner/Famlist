/*
 CatalogLocalStore.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lokale Kopie des Artikelstamms und Warteschlange noch nicht gesendeter Änderungen, gespeichert
   als JSON-Dateien im Ordner Application Support (bleibt über App-Neustarts erhalten).

 🔰 Notes for Beginners:
 - `entries` = zuletzt vom Server geladener Stand + alle wartenden Aufträge (in Reihenfolge).
 - Dateien statt UserDefaults: Einträge können Fotos (Base64) enthalten und damit groß werden.
 - Beim Abmelden wird alles gelöscht (`clear()`), damit kein fremder Artikelstamm und keine
   fremden Aufträge beim nächsten Konto landen.

 📝 Last Change:
 - Initial creation (Artikelstamm offline zuerst).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class CatalogLocalStore {
    /// Wartender Auftrag mit Zahl der Fehlversuche (ohne Netzfehler).
    struct Pending: Codable, Equatable {
        var operation: CatalogOperation
        var failures = 0
    }

    private let cacheURL: URL
    private let outboxURL: URL
    private(set) var cache: [ItemCatalogEntry]?
    private(set) var outbox: [Pending]

    init(directory: URL = CatalogLocalStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("item_catalog_cache.json")
        outboxURL = directory.appendingPathComponent("item_catalog_outbox.json")
        cache = Self.read([ItemCatalogEntry].self, from: cacheURL)
        outbox = Self.read([Pending].self, from: outboxURL) ?? []
    }

    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ItemCatalog", isDirectory: true)
    }

    /// Server-Stand plus wartende Aufträge; nil, solange noch nie geladen wurde.
    var entries: [ItemCatalogEntry]? {
        guard let cache else { return outbox.isEmpty ? nil : outbox.reduce([]) { $1.operation.apply(to: $0) } }
        return outbox.reduce(cache) { $1.operation.apply(to: $0) }
    }

    func setCache(_ entries: [ItemCatalogEntry]) {
        cache = entries
        Self.write(entries, to: cacheURL)
    }

    func append(_ operation: CatalogOperation) {
        outbox.append(Pending(operation: operation))
        Self.write(outbox, to: outboxURL)
    }

    func removeFirst() {
        guard !outbox.isEmpty else { return }
        outbox.removeFirst()
        Self.write(outbox, to: outboxURL)
    }

    func recordFailure() {
        guard !outbox.isEmpty else { return }
        outbox[0].failures += 1
        Self.write(outbox, to: outboxURL)
    }

    func clear() {
        cache = nil
        outbox = []
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.removeItem(at: outboxURL)
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        LocalJSONFile.read(type, from: url)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        LocalJSONFile.write(value, to: url)
    }
}
