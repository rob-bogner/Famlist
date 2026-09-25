/*
 ItemImagePrefetcher.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lädt Fotos, die andere Geräte hochgeladen haben, sofort nach dem Abgleich herunter und legt sie
   lokal in SwiftData ab – für ALLE Listen, nicht erst beim Anzeigen. So sind Fotos auch offline da.

 🔰 Notes for Beginners:
 - Kandidaten: Artikel mit `imagePath`, aber ohne lokale Kopie (`imageData == nil`).
 - Höchstens 3 Downloads gleichzeitig; ein Artikel wird nie doppelt geladen.
 - Die lokale Kopie ändert weder HLC noch Sync-Status: Sie wird nicht zurückgesendet.
 - Fehler (offline, Datei fehlt) sind unkritisch: Der nächste Lauf versucht es erneut.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Fotos in Storage, offline verfügbar).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ItemImagePrefetcher {
    static let maxConcurrent = 3
    static let batchLimit = 60

    private let store: SwiftDataItemStore
    private let storage: ImageStorage
    private var inFlight: Set<UUID> = []
    private var isRunning = false
    private let onUpdate: @MainActor () -> Void

    init(store: SwiftDataItemStore, storage: ImageStorage, onUpdate: @escaping @MainActor () -> Void) {
        self.store = store
        self.storage = storage
        self.onUpdate = onUpdate
    }

    /// Lädt alle fehlenden Fotos. Mehrfache Aufrufe während eines Laufs werden zusammengefasst.
    func prefetchMissing() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        var failed: Set<UUID> = []
        while true {
            let candidates = (try? store.itemsMissingImage(limit: Self.batchLimit,
                                                           excluding: failed.union(inFlight))) ?? []
            guard !candidates.isEmpty else { break }
            let jobs = candidates.compactMap { entity in entity.imagePath.map { (entity.id, $0) } }
            let loaded = await download(jobs)
            failed.formUnion(Set(jobs.map(\.0)).subtracting(loaded.keys))
            for (id, data) in loaded {
                guard let entity = try? store.fetchItem(id: id) else { continue }
                // Nur übernehmen, wenn der Pfad inzwischen nicht gewechselt hat.
                if entity.imagePath == jobs.first(where: { $0.0 == id })?.1 {
                    entity.imageData = data.base64EncodedString()
                }
            }
            try? store.save()
            if !loaded.isEmpty { onUpdate() }
            // Kein Abbruch bei einer Runde ohne Erfolg: Fehlgeschlagene sind ausgeschlossen, die nächste Runde
            // nimmt andere Artikel; die Schleife endet, wenn keine Kandidaten mehr übrig sind.
        }
    }

    private func download(_ jobs: [(UUID, String)]) async -> [UUID: Data] {
        jobs.forEach { inFlight.insert($0.0) }
        defer { jobs.forEach { inFlight.remove($0.0) } }
        var results: [UUID: Data] = [:]
        var index = 0
        while index < jobs.count {
            let slice = jobs[index..<min(index + Self.maxConcurrent, jobs.count)]
            await withTaskGroup(of: (UUID, Data?).self) { group in
                for (id, path) in slice {
                    // Ohne @MainActor: storage ist Sendable, download(...) läuft ohnehin auf dem Main Actor.
                    group.addTask { [storage] in
                        (id, try? await storage.download(bucket: ProductImageCodec.itemBucket, path: path))
                    }
                }
                for await (id, data) in group { if let data { results[id] = data } }
            }
            index += Self.maxConcurrent
        }
        return results
    }
}
