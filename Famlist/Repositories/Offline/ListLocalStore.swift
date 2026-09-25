/*
 ListLocalStore.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lokale Kopie der Listen (eigene und geteilte) und Warteschlange der Listen-Aufträge,
   gespeichert als JSON in Application Support/Lists.

 🔰 Notes for Beginners:
 - Gleiches Muster wie CatalogLocalStore: `lists` = Server-Stand + wartende Aufträge.
 - Dateischutz: bis zur ersten Entsperrung verschlüsselt.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Listen offline).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ListLocalStore {
    struct Pending: Codable, Equatable {
        var operation: ListOperation
        var failures = 0
    }

    private let cacheURL: URL
    private let outboxURL: URL
    private(set) var cache: [ListModel]?
    private(set) var outbox: [Pending]

    init(directory: URL = ListLocalStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("lists_cache.json")
        outboxURL = directory.appendingPathComponent("lists_outbox.json")
        cache = Self.read([ListModel].self, from: cacheURL)
        outbox = Self.read([Pending].self, from: outboxURL) ?? []
    }

    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lists", isDirectory: true)
    }

    /// Server-Stand plus wartende Aufträge; nil, solange noch nie etwas geladen oder angelegt wurde.
    var lists: [ListModel]? {
        guard let cache else { return outbox.isEmpty ? nil : outbox.reduce([]) { $1.operation.apply(to: $0) } }
        return outbox.reduce(cache) { $1.operation.apply(to: $0) }
    }

    func setCache(_ lists: [ListModel]) {
        cache = lists
        Self.write(lists, to: cacheURL)
    }

    func append(_ operation: ListOperation) {
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
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
