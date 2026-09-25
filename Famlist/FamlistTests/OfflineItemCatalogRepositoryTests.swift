/*
 OfflineItemCatalogRepositoryTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikelstamm offline zuerst: Schreiben ohne Netz, Anzeige aus lokaler Kopie + Warteschlange,
   Senden in Reihenfolge bei Wiederverbindung, abgelehnte Aufträge, Abmelden.
 - Übernahme von Artikelstamm-Änderungen in die geöffnete Liste.

 🔰 Notes for Beginners:
 - Jeder Test nutzt einen eigenen temporären Ordner für die JSON-Dateien (kein gemeinsamer Zustand).

 📝 Last Change:
 - Initial creation (Artikelstamm offline zuerst).
 ------------------------------------------------------------------------
 */

import Combine
import SwiftData
import XCTest
@testable import Famlist

/// „Server“, der offline einen URLError wirft und jeden Aufruf mitschreibt.
@MainActor
private final class FlakyCatalog: ItemCatalogRepository {
    var entries: [ItemCatalogEntry]
    var online = true
    var rejectUpdates = false
    private(set) var sent: [String] = []
    init(_ entries: [ItemCatalogEntry]) { self.entries = entries }

    private func check() throws { if !online { throw URLError(.notConnectedToInternet) } }

    func search(query: String) async throws -> [ItemCatalogEntry] {
        try check()
        return entries.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
    func save(_ entry: ItemCatalogEntry) async throws {
        try check(); sent.append("save \(entry.name)")
        if let i = entries.firstIndex(where: { $0.name.lowercased() == entry.name.lowercased() }) {
            entries[i].measure = entry.measure
        } else { entries.append(entry) }
    }
    func fetchAll() async throws -> [ItemCatalogEntry] { try check(); return entries }
    func update(_ entry: ItemCatalogEntry) async throws {
        try check()
        if rejectUpdates { throw NSError(domain: "PostgREST", code: 23505) }
        sent.append("update \(entry.name) \(entry.measure)")
        if let i = entries.firstIndex(where: { $0.id == entry.id }) { entries[i] = entry }
    }
    func delete(id: String) async throws { try check(); sent.append("delete \(id)"); entries.removeAll { $0.id == id } }
}

private final class SyncSpy: SyncEngineProtocol {
    var updated: [ItemModel] = []
    func createItem(_ item: ItemModel) async {}
    func updateItem(_ item: ItemModel) async { updated.append(item) }
    func deleteItem(_ item: ItemModel) async {}
    func resumeSync() async {}
    func retryItem(_ item: ItemModel) async {}
    func applyBulkItems(_ targets: [ImportTarget]) async {}
}

@MainActor
final class OfflineItemCatalogRepositoryTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func entry(_ name: String, measure: String = "") -> ItemCatalogEntry {
        ItemCatalogEntry(id: name, ownerPublicId: "me", name: name, brand: nil, category: nil,
                         productDescription: nil, measure: measure, price: 0, imageData: nil)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    func test_offlineUpdate_doesNotThrow_showsLocally_andSendsOnReconnect() async throws {
        let remote = FlakyCatalog([entry("Butter"), entry("Milch")])
        let reconnect = PassthroughSubject<Bool, Never>()
        let repo = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory),
                                                reconnect: reconnect.eraseToAnyPublisher())
        _ = try await repo.fetchAll()                    // lokale Kopie anlegen
        remote.online = false

        var butter = entry("Butter"); butter.measure = "Packung"
        try await repo.update(butter)
        try await repo.delete(id: "Milch")
        XCTAssertEqual(repo.pendingCount, 2)
        let offline = try await repo.fetchAll()
        XCTAssertEqual(offline.map(\.name), ["Butter"], "Löschen offline sichtbar")
        XCTAssertEqual(offline.first?.measure, "Packung", "Ändern offline sichtbar")

        remote.online = true
        reconnect.send(true)
        await waitUntil { repo.pendingCount == 0 }
        XCTAssertEqual(remote.sent, ["update Butter Packung", "delete Milch"], "Reihenfolge wie getippt")
        XCTAssertEqual(remote.entries.map(\.measure), ["Packung"])
    }

    func test_queueSurvivesRestart() async throws {
        let remote = FlakyCatalog([entry("Butter")])
        remote.online = false
        let first = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        try await first.update(entry("Butter", measure: "g"))

        remote.online = true
        let restarted = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        XCTAssertEqual(restarted.pendingCount, 1, "Warteschlange liegt in einer Datei")
        await restarted.flush()
        XCTAssertEqual(remote.entries.first?.measure, "g")
    }

    func test_offlineWithoutCache_fetchAllThrows() async {
        let remote = FlakyCatalog([entry("Butter")])
        remote.online = false
        let repo = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        do {
            _ = try await repo.fetchAll()
            XCTFail("Ohne lokale Kopie muss der Fehler ankommen")
        } catch {}
    }

    func test_offlineSearch_usesLocalCopy() async throws {
        let remote = FlakyCatalog([entry("Butter"), entry("Buttermilch"), entry("Brot")])
        let repo = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        _ = try await repo.fetchAll()
        remote.online = false
        let hits = try await repo.search(query: "butter")
        XCTAssertEqual(hits.map(\.name), ["Butter", "Buttermilch"])
    }

    func test_rejectedOperation_droppedAfterMaxFailures() async throws {
        let remote = FlakyCatalog([entry("Butter")])
        remote.rejectUpdates = true
        let repo = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        try await repo.update(entry("Butter", measure: "g"))
        for _ in 1..<OfflineItemCatalogRepository.maxFailures { await repo.flush() }
        XCTAssertEqual(repo.pendingCount, 0, "Abgelehnter Auftrag blockiert die Warteschlange nicht ewig")
    }

    func test_clearLocalData_dropsCacheAndQueue() async throws {
        let remote = FlakyCatalog([entry("Butter")])
        let repo = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        _ = try await repo.fetchAll()
        remote.online = false
        try await repo.update(entry("Butter", measure: "g"))
        repo.clearLocalData()
        XCTAssertEqual(repo.pendingCount, 0)
        XCTAssertEqual(CatalogLocalStore(directory: directory).outbox.count, 0)
        XCTAssertNil(CatalogLocalStore(directory: directory).entries)
    }

    func test_saveOperation_upsertsByName_keepingId() {
        let existing = [entry("Butter")]
        var incoming = entry("butter", measure: "g")
        incoming.id = "new-id"
        let result = CatalogOperation.save(incoming).apply(to: existing)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "Butter")
        XCTAssertEqual(result.first?.measure, "g")
    }

    // MARK: - Übernahme in die Liste

    func test_applyCatalogEdit_updatesOnlyChangedFields_ofMatchingListItems() async throws {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let vm = ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                               itemStore: SwiftDataItemStore(context: context),
                               listStore: SwiftDataListStore(context: context), startImmediately: false)
        let spy = SyncSpy()
        vm.configure(syncEngine: spy)
        vm.items = [ItemModel(id: "1", name: "butter ", units: 3, measure: "", price: 1.99, isChecked: true, brand: "Eigene"),
                    ItemModel(id: "2", name: "Milch", units: 1, measure: "")]

        var old = entry("Butter"); old.brand = "Kerrygold"; old.price = 2.49
        var new = old; new.measure = "pack"
        let changed = vm.applyCatalogEdit(from: old, to: new)

        XCTAssertEqual(changed, 1, "nur gleichnamige Artikel (ohne Groß/klein, Leerzeichen)")
        await waitUntil { !spy.updated.isEmpty }
        XCTAssertEqual(spy.updated.count, 1)
        let updated = try XCTUnwrap(spy.updated.first, "über die SyncEngine gespeichert (offline zuerst)")
        XCTAssertEqual(updated.id, "1")
        XCTAssertEqual(updated.measure, "pack", "geänderte Maßeinheit übernommen")
        XCTAssertEqual(updated.units, 3, "Menge bleibt")
        XCTAssertTrue(updated.isChecked, "Abhak-Status bleibt")
        XCTAssertEqual(updated.brand, "Eigene", "unveränderte Felder überschreiben die Liste nicht")
        XCTAssertEqual(updated.price, 1.99, accuracy: 0.001)
    }

    func test_applyCatalogEdit_noChange_noWrite() throws {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let vm = ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                               itemStore: SwiftDataItemStore(context: context),
                               listStore: SwiftDataListStore(context: context), startImmediately: false)
        vm.items = [ItemModel(id: "1", name: "Butter", units: 1, measure: "pack")]
        XCTAssertEqual(vm.applyCatalogEdit(from: entry("Butter", measure: "pack"), to: entry("Butter", measure: "pack")), 0)
    }
}
