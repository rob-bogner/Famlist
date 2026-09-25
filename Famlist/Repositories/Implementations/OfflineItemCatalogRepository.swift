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
 - Initial creation (Artikelstamm offline zuerst).
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
            store.setCache(try await remote.fetchAll())
        } catch where store.entries != nil {
            logVoid(params: (action: "catalog.fetchAll.offline", pending: store.outbox.count))
        }
        return store.entries ?? []
    }

    func search(query: String) async throws -> [ItemCatalogEntry] {
        await flush()
        if store.outbox.isEmpty, let remoteHits = try? await remote.search(query: query) { return remoteHits }
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
