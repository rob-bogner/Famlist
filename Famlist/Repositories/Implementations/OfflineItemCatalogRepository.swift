/*
 OfflineItemCatalogRepository.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikelstamm offline zuerst: legt sich vor das Supabase-Repository. Änderungen werden lokal
   gespeichert und in einer Warteschlange nacheinander gesendet – sofort, und ohne Netz dann,
   sobald wieder Verbindung besteht.

 🔰 Notes for Beginners:
 - Schreiben (save/update/delete) wirft nie wegen fehlendem Netz: Der Auftrag bleibt in der
   Warteschlange (CatalogLocalStore) und die Anzeige zeigt sofort den neuen Stand.
 - Lesen (fetchAll/search/find): mit Netz vom Server (und als lokale Kopie merken), ohne Netz aus
   der lokalen Kopie. Wartende Aufträge sind immer eingerechnet.
 - Netzfehler (URLError) → Auftrag bleibt, Senden stoppt. Andere Fehler (z. B. vom Server
   abgelehnt) → nach `maxFailures` Versuchen verworfen, damit die Warteschlange nicht hängen bleibt.
 - Wieder online: `reconnect` (ConnectivityMonitor.$isOnline) löst das Senden aus.

 📝 Last Change:
 - Fotos aus Storage lokal vorhalten, alte Base64-Fotos umziehen (Audit 25.09.2026, Migration 016).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation

@MainActor
final class OfflineItemCatalogRepository: ItemCatalogRepository {
    static let maxFailures = 5

    private let remote: any ItemCatalogRepository
    let store: CatalogLocalStore
    private var flushTask: Task<Void, Never>?
    private var reconnectSubscription: AnyCancellable?
    private var didMigrateLegacyImages = false

    init(remote: any ItemCatalogRepository, store: CatalogLocalStore? = nil,
         reconnect: AnyPublisher<Bool, Never>? = nil) {
        self.remote = remote
        self.store = store ?? CatalogLocalStore()
        reconnectSubscription = reconnect?
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in Task { await self?.flush() } }
    }

    var pendingCount: Int { store.outbox.count }

    // MARK: - Schreiben

    func save(_ entry: ItemCatalogEntry) async throws { await enqueue(.save(entry)) }
    func update(_ entry: ItemCatalogEntry) async throws { await enqueue(.update(entry)) }
    func delete(id: String) async throws { await enqueue(.delete(id: id)) }

    private func enqueue(_ operation: CatalogOperation) async {
        store.append(operation)
        await flush()
    }

    // MARK: - Lesen

    func fetchAll() async throws -> [ItemCatalogEntry] {
        await flush()
        do {
            let remoteEntries = try await remote.fetchAll()
            store.setCache(await withLocalImages(remoteEntries))
            await migrateLegacyImagesOnce(remoteEntries)
        } catch where store.entries != nil {
            logVoid(params: (action: "catalog.fetchAll.offline", pending: store.outbox.count))
        }
        return store.entries ?? []
    }

    /// Fotos lokal bereithalten (offline verfügbar): vorhandene Kopie bei gleichem Pfad übernehmen,
    /// sonst einmal herunterladen.
    private func withLocalImages(_ entries: [ItemCatalogEntry]) async -> [ItemCatalogEntry] {
        let cached = Dictionary((store.entries ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [ItemCatalogEntry] = []
        for var entry in entries {
            if let path = entry.imagePath {
                if let local = cached[entry.id], local.imagePath == path, local.imageData != nil {
                    entry.imageData = local.imageData
                } else if let data = try? await remote.downloadImage(path: path) {
                    entry.imageData = data.base64EncodedString()
                }
            }
            result.append(entry)
        }
        return result
    }

    /// Alte Base64-Fotos (ohne Pfad) einmal je Sitzung nach Storage umziehen (Migration 016).
    private func migrateLegacyImagesOnce(_ entries: [ItemCatalogEntry]) async {
        guard !didMigrateLegacyImages else { return }
        didMigrateLegacyImages = true
        let legacy = entries.filter { $0.imagePath == nil && $0.imageData != nil }
        guard !legacy.isEmpty else { return }
        logVoid(params: (action: "catalog.migrateLegacyImages", count: legacy.count))
        for entry in legacy { store.append(.update(entry)) }
        await flush()
    }

    func search(query: String) async throws -> [ItemCatalogEntry] {
        await flush()
        if store.outbox.isEmpty, let remoteHits = try? await remote.search(query: query) {
            // Fotos aus der lokalen Kopie ergänzen (Treffer vom Server tragen nur den Pfad).
            let cached = Dictionary((store.entries ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return remoteHits.map { hit in
                var entry = hit
                if entry.imageData == nil, let local = cached[hit.id], local.imagePath == hit.imagePath {
                    entry.imageData = local.imageData
                }
                return entry
            }
        }
        let q = CatalogOperation.key(query)
        return Array((store.entries ?? []).filter { CatalogOperation.key($0.name).contains(q) }.prefix(5))
    }

    func find(barcode: String) async throws -> ItemCatalogEntry? {
        await flush()
        if store.outbox.isEmpty, let hit = try? await remote.find(barcode: barcode) { return hit }
        return store.entries?.first { $0.barcode == barcode }
    }

    // MARK: - Senden

    /// Sendet die Warteschlange der Reihe nach. Läuft schon ein Durchgang, wird auf ihn gewartet.
    func flush() async {
        while let running = flushTask { await running.value }
        guard !store.outbox.isEmpty else { return }
        // Der Durchgang räumt sich selbst ab; sonst könnten Wartende sich im Kreis drehen,
        // bevor dieser Aufrufer wieder an der Reihe ist.
        let task = Task { await self.drain(); self.flushTask = nil }
        flushTask = task
        await task.value
    }

    private func drain() async {
        while let pending = store.outbox.first {
            do {
                try await send(pending.operation)
                store.removeFirst()
            } catch let error as URLError {
                logVoid(params: (action: "catalog.flush.offline", code: error.code.rawValue, pending: store.outbox.count))
                return
            } catch {
                store.recordFailure()
                logVoid(params: (action: "catalog.flush.rejected", failures: pending.failures + 1,
                                 error: (error as NSError).localizedDescription))
                if pending.failures + 1 >= Self.maxFailures { store.removeFirst() } else { return }
            }
        }
    }

    private func send(_ operation: CatalogOperation) async throws {
        switch operation {
        case .save(let entry): try await remote.save(entry)
        case .update(let entry): try await remote.update(entry)
        case .delete(let id): try await remote.delete(id: id)
        }
    }

    /// Abmelden: lokale Kopie und Warteschlange verwerfen (gehören zum abgemeldeten Konto).
    func clearLocalData() {
        store.clear()
    }
}
