/*
 CatalogUsageTests.swift
 FamlistTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zähler „Oft gekauft“ (Migration 022): Hinzufügen erzeugt einen Zähl-Auftrag – auch offline, immer
   NACH dem Speichern des Artikelstamm-Eintrags –, lokale Anzeige zählt mit, Sortierung stimmt,
   große Mengen gehen in Teilen zu 200 Namen an die RPC.

 🔰 Notes for Beginners:
 - Jeder Test nutzt einen eigenen temporären Ordner für die JSON-Dateien (kein gemeinsamer Zustand).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 3).
 ------------------------------------------------------------------------
 */

import Supabase
import SwiftData
import XCTest
@testable import Famlist

/// Artikelstamm-„Server“, der offline einen URLError wirft und jeden Aufruf mitschreibt.
@MainActor
private final class RecordingCatalog: ItemCatalogRepository {
    var entries: [ItemCatalogEntry] = []
    var online = true
    private(set) var sent: [String] = []

    private func check() throws { if !online { throw URLError(.notConnectedToInternet) } }

    func search(query: String) async throws -> [ItemCatalogEntry] { try check(); return [] }
    func save(_ entry: ItemCatalogEntry) async throws {
        try check(); sent.append("save \(entry.name)")
        if !entries.contains(where: { $0.name.lowercased() == entry.name.lowercased() }) { entries.append(entry) }
    }
    func fetchAll() async throws -> [ItemCatalogEntry] { try check(); return entries }
    func noteUse(names: [String], at date: Date) async throws {
        try check(); sent.append("use \(names.joined(separator: ","))")
    }
}

/// Minimaler Client: zeichnet RPC-Aufrufe mit der Zahl der übergebenen Namen auf.
private final class RPCRecordingClient: SupabaseClienting, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(function: String, names: Int)] = []
    var calls: [(function: String, names: Int)] { lock.withLock { _calls } }

    var auth: any AuthClienting { fatalError("auth not needed") }
    var realtime: RealtimeClientV2 { fatalError("realtime not needed") }
    func from(_ table: String) -> PostgrestQueryBuilder { fatalError("from not needed") }
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {}
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String { "" }
    func rpcValue<P: Encodable & Sendable, R: Decodable & Sendable>(_ function: String, params: P) async throws -> R {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [String: Any]
        let names = (json?["p_names"] as? [String])?.count ?? -1
        lock.withLock { _calls.append((function, names)) }
        return try JSONDecoder().decode(R.self, from: Data("\(names)".utf8))
    }
}

/// SyncEngine-Spion: merkt sich Änderungen (schreibt nichts in SwiftData).
private final class RecordingSync: SyncEngineProtocol {
    private(set) var updated: [ItemModel] = []
    func createItem(_ item: ItemModel) async {}
    func updateItem(_ item: ItemModel) async { updated.append(item) }
    func deleteItem(_ item: ItemModel) async {}
    func resumeSync() async {}
    func retryItem(_ item: ItemModel) async {}
    func applyBulkItems(_ targets: [ImportTarget]) async {}
}

@MainActor
final class CatalogUsageTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func entry(_ name: String, uses: Int? = nil, lastUsed: Date? = nil) -> ItemCatalogEntry {
        var entry = ItemCatalogEntry(id: name, ownerPublicId: "me", name: name, brand: nil, category: nil,
                                     productDescription: nil, measure: "", price: 0, imageData: nil)
        entry.useCount = uses
        entry.lastUsedAt = lastUsed
        return entry
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<300 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    private var sync = RecordingSync()

    private func makeListViewModel(catalog: any ItemCatalogRepository) throws -> ListViewModel {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let vm = ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                               itemStore: SwiftDataItemStore(context: context),
                               listStore: SwiftDataListStore(context: context), startImmediately: false)
        vm.configure(syncEngine: sync)
        vm.configure(catalogRepository: catalog)
        return vm
    }

    // MARK: - Offline-Warteschlange

    func test_offlineAdd_queuesSaveThenUse_countsLocally_andSendsInOrder() async throws {
        let remote = RecordingCatalog()
        let repo = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        _ = try await repo.fetchAll()                                   // lokale Kopie (leer) anlegen
        remote.online = false

        let usedAt = Date(timeIntervalSince1970: 1_790_000_000)
        try await repo.save(entry("Milch"))
        try await repo.noteUse(names: ["milch"], at: usedAt)
        XCTAssertEqual(repo.pendingCount, 2, "beide Aufträge warten offline")

        let local = try await repo.fetchAll()
        XCTAssertEqual(local.first?.useCount, 1, "Zähler offline sichtbar (Groß/klein egal)")
        XCTAssertEqual(local.first?.lastUsedAt, usedAt)

        remote.online = true
        await repo.flush()
        XCTAssertEqual(remote.sent, ["save Milch", "use milch"], "Zählen erst nach dem Speichern")
        XCTAssertEqual(repo.pendingCount, 0)
    }

    func test_noteUseQueue_survivesRestart() async throws {
        let remote = RecordingCatalog()
        remote.online = false
        let first = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        try await first.noteUse(names: ["Brot"], at: Date())

        remote.online = true
        let restarted = OfflineItemCatalogRepository(remote: remote, store: CatalogLocalStore(directory: directory))
        XCTAssertEqual(restarted.pendingCount, 1, "Zähl-Auftrag liegt in der Datei")
        await restarted.flush()
        XCTAssertEqual(remote.sent, ["use Brot"])
    }

    func test_emptyNames_createNoOperation() async throws {
        let repo = OfflineItemCatalogRepository(remote: RecordingCatalog(), store: CatalogLocalStore(directory: directory))
        try await repo.noteUse(names: [], at: Date())
        XCTAssertEqual(repo.pendingCount, 0)
    }

    // MARK: - Lokale Anwendung (wie die RPC)

    func test_noteUse_countsEachName_ignoresUnknown_andNeverMovesBack() {
        let recent = Date(timeIntervalSince1970: 1_790_000_000)
        let older = recent.addingTimeInterval(-3_600)
        let start = [entry("Milch", uses: 2, lastUsed: recent), entry("Brot")]

        let result = CatalogOperation.noteUse(names: ["MILCH", "milch", "Käse", "Brot"], at: older).apply(to: start)
        let milch = result.first { $0.name == "Milch" }
        let brot = result.first { $0.name == "Brot" }
        XCTAssertEqual(milch?.useCount, 4, "gleicher Name zweimal = +2")
        XCTAssertEqual(milch?.lastUsedAt, recent, "älterer Zeitpunkt setzt die letzte Nutzung nicht zurück")
        XCTAssertEqual(brot?.useCount, 1)
        XCTAssertEqual(brot?.lastUsedAt, older)
        XCTAssertEqual(result.count, 2, "unbekannter Name legt keinen Eintrag an")
    }

    func test_noteUse_futureDate_isClampedToNow() {
        let result = CatalogOperation.noteUse(names: ["Milch"], at: Date().addingTimeInterval(86_400)).apply(to: [entry("Milch")])
        XCTAssertLessThanOrEqual(try XCTUnwrap(result.first?.lastUsedAt), Date())
    }

    func test_saveAndUpdate_keepCounter() {
        let used = Date(timeIntervalSince1970: 1_790_000_000)
        let start = [entry("Milch", uses: 5, lastUsed: used)]
        let saved = CatalogOperation.save(entry("milch")).apply(to: start)
        XCTAssertEqual(saved.first?.useCount, 5, "Upsert aus der Liste setzt den Zähler nicht zurück")
        XCTAssertEqual(saved.first?.lastUsedAt, used)

        let updated = CatalogOperation.update(entry("Milch")).apply(to: start)
        XCTAssertEqual(updated.first?.useCount, 5, "Bearbeiten setzt den Zähler nicht zurück")
    }

    // MARK: - Sortierung „Oft gekauft“

    func test_frequentlyUsed_ordersByCountThenRecency_andSkipsUnused() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let entries = [
            entry("Äpfel", uses: 3, lastUsed: now.addingTimeInterval(-10)),
            entry("Butter", uses: 7, lastUsed: now.addingTimeInterval(-500)),
            entry("Milch", uses: 3, lastUsed: now),
            entry("Brot", uses: 0, lastUsed: nil),
            entry("Eier", uses: nil, lastUsed: nil),
            entry("Käse", uses: 3, lastUsed: now)
        ]
        XCTAssertEqual(ItemCatalogEntry.frequentlyUsed(entries).map(\.name), ["Butter", "Käse", "Milch", "Äpfel"],
                       "Zähler absteigend, dann zuletzt benutzt, dann alphabetisch; nie benutzte fehlen")
        XCTAssertEqual(ItemCatalogEntry.frequentlyUsed(entries, limit: 2).map(\.name), ["Butter", "Käse"])
    }

    func test_frequentlyUsed_defaultLimitIsEight() {
        let entries = (1...12).map { (number: Int) in entry("Artikel \(number)", uses: number) }
        XCTAssertEqual(ItemCatalogEntry.frequentlyUsed(entries).count, 8)
        XCTAssertEqual(ItemCatalogEntry.frequentlyUsed(entries).first?.name, "Artikel 12")
    }

    // MARK: - Hinzufügen in der Liste

    func test_addItem_savesToCatalogThenCountsUse() async throws {
        let catalog = RecordingCatalog()
        let vm = try makeListViewModel(catalog: catalog)
        vm.addItem(ItemModel(name: "Hafermilch", units: 1, measure: ""))
        await waitUntil { catalog.sent.count >= 2 }
        XCTAssertEqual(catalog.sent, ["save Hafermilch", "use Hafermilch"])
    }

    func test_addingExistingOpenItem_countsUseAgain() async throws {
        let catalog = RecordingCatalog()
        let vm = try makeListViewModel(catalog: catalog)
        vm.items = [ItemModel(id: "1", name: "Brot", units: 1, measure: "")]    // offen in der Liste
        vm.addItem(ItemModel(name: "brot", units: 1, measure: ""))
        await waitUntil { catalog.sent.contains("use Brot") && !self.sync.updated.isEmpty }
        XCTAssertEqual(sync.updated.map(\.units), [2], "Duplikat erhöht die Menge")
        XCTAssertEqual(catalog.sent, ["save Brot", "use Brot"], "Eintrag gespeichert, dann gezählt")
    }

    func test_bulkImport_countsAllImportedNames() async throws {
        let catalog = RecordingCatalog()
        let vm = try makeListViewModel(catalog: catalog)
        let targets: [ImportTarget] = [.createNew(ItemModel(name: "Eier", units: 1, measure: "")),
                                       .update(ItemModel(name: "Mehl", units: 2, measure: ""))]
        vm.applyBulkImport(ImportMergeService.MergeResult(targets: targets))
        await waitUntil { !catalog.sent.isEmpty }
        XCTAssertEqual(catalog.sent, ["use Eier,Mehl"])
    }

    // MARK: - Supabase-RPC

    func test_supabaseNoteUse_sendsChunksOf200() async throws {
        let client = RPCRecordingClient()
        let repo = SupabaseItemCatalogRepository(client: client)
        try await repo.noteUse(names: (1...450).map { "Artikel \($0)" }, at: Date())
        XCTAssertEqual(client.calls.map(\.function), Array(repeating: "catalog_note_use", count: 3))
        XCTAssertEqual(client.calls.map(\.names), [200, 200, 50])
    }
}
