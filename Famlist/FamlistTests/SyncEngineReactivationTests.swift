/*
 SyncEngineReactivationTests.swift
 FamlistTests
 Created on: 18.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests der SyncEngine (Audit 25.09.2026):
   Offline-Betrieb, Fehlerklassen, Zusammenfassen der Warteschlange, Server-Antworten
   (applied/stale/denied), Neu-Anlegen nach Löschen, Löschen nie gesendeter Artikel,
   gebündeltes Senden, Foto nur bei Änderung, Umbenennen-Kollision, Abmelden.

 📝 Last Change:
 - Neu geschrieben für die überarbeitete SyncEngine (ein Schreibweg, RPC upsert_items_lww).
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
import Supabase
@testable import Famlist

// MARK: - Spy Repository

@MainActor
private final class SpyItemsRepository: ItemsRepository {
    /// Jeder Aufruf von upsertItems mit seinen Aufträgen.
    var calls: [[ItemUpsertRequest]] = []
    /// Nächster Fehler (wird einmal geworfen).
    var nextError: Error?
    /// Antwort je Auftrag; Standard: übernommen (Echo des Auftrags).
    var responder: (ItemUpsertRequest) -> ItemUpsertResult = {
        ItemUpsertResult(id: $0.item.id, status: .applied, item: $0.item, message: nil)
    }

    var sentItems: [ItemModel] { calls.flatMap { $0.map(\.item) } }

    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] {
        calls.append(requests)
        if let error = nextError {
            nextError = nil
            throw error
        }
        return requests.map(responder)
    }

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { AsyncStream { _ in } }
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] { [] }
}

// MARK: - Tests

@MainActor
final class SyncEngineReactivationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var spy: SpyItemsRepository!
    private var itemStore: SwiftDataItemStore!
    private var queue: SyncOperationQueue!
    private var sut: SyncEngine!
    private var online = true
    private var events: [SyncEvent] = []
    private let listId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

    override func setUp() async throws {
        container = PersistenceController(inMemory: true).container
        context = container.mainContext
        spy = SpyItemsRepository()
        itemStore = SwiftDataItemStore(context: context)
        queue = SyncOperationQueue(context: context)
        online = true
        events = []
        sut = SyncEngine(repository: spy, itemStore: itemStore, operationQueue: queue,
                         hlcGenerator: HybridLogicalClockGenerator(nodeId: "test-node"),
                         isOnline: { [unowned self] in self.online })
        sut.setSyncEventObserver { [unowned self] in self.events.append($0) }
    }

    override func tearDown() async throws {
        sut = nil
        spy = nil
        queue = nil
        itemStore = nil
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func item(_ name: String, units: Int = 1, image: String? = nil) -> ItemModel {
        ItemModel(imageData: image, name: name, units: units, listId: listId.uuidString)
    }

    private func entity(named name: String) throws -> ItemEntity {
        try XCTUnwrap(itemStore.fetchItem(id: UUID.deterministicItemID(listId: listId, name: name)))
    }

    @discardableResult
    private func insertTombstoned(_ name: String, hlcTimestamp: Int64) throws -> ItemEntity {
        var model = item(name)
        model = model.withId(UUID.deterministicItemID(listId: listId, name: name).uuidString)
        model.hlcTimestamp = hlcTimestamp
        model.hlcCounter = 0
        model.hlcNodeId = "other-node"
        model.tombstone = true
        let entity = try itemStore.upsert(model: model)
        try itemStore.save()
        return entity
    }

    // MARK: - Anlegen

    func test_createItem_sendsFullStateWithHLC_andMarksSynced() async throws {
        await sut.createItem(item("Milch"))

        let sent = try XCTUnwrap(spy.sentItems.first)
        XCTAssertEqual(sent.id, UUID.deterministicItemID(listId: listId, name: "Milch").uuidString)
        XCTAssertEqual(sent.tombstone, false)
        XCTAssertNotNil(sent.hlcTimestamp)
        XCTAssertEqual(sent.hlcNodeId, "test-node")
        XCTAssertEqual(try entity(named: "Milch").syncStatus, .synced)
        XCTAssertEqual(queue.count, 0)
    }

    func test_reAddAfterDeletion_usesNewerHLC_andIsVisible() async throws {
        let future = Int64(Date().timeIntervalSince1970 * 1000) + 60_000   // Löschung von einem Gerät mit vorgehender Uhr
        try insertTombstoned("Milch", hlcTimestamp: future)

        await sut.createItem(item("Milch", units: 2))

        let sent = try XCTUnwrap(spy.sentItems.last)
        XCTAssertEqual(sent.tombstone, false)
        XCTAssertGreaterThan(sent.hlc, HybridLogicalClock(timestamp: future, counter: 0, nodeId: "other-node"))
        XCTAssertEqual(try itemStore.fetchItems(listId: listId).map(\.units), [2])
    }

    func test_createItem_whenDeterministicIdHoldsRenamedItem_getsOwnId() async throws {
        var renamed = item("Hafermilch")
        renamed = renamed.withId(UUID.deterministicItemID(listId: listId, name: "Milch").uuidString)
        try itemStore.upsert(model: renamed)
        try itemStore.save()

        await sut.createItem(item("Milch"))

        let milch = try XCTUnwrap(spy.sentItems.last)
        XCTAssertNotEqual(milch.id, renamed.id, "Hafermilch darf nicht überschrieben werden")
        XCTAssertEqual(try itemStore.fetchItems(listId: listId).map(\.name).sorted(), ["Hafermilch", "Milch"])
    }

    // MARK: - Offline

    func test_offline_nothingIsSent_andNothingFails() async throws {
        online = false
        await sut.createItem(item("Brot"))
        await sut.resumeSync()

        XCTAssertTrue(spy.calls.isEmpty)
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.failedCount, 0)
        XCTAssertEqual(try entity(named: "Brot").syncStatus, .pendingCreate)
        XCTAssertEqual(try itemStore.fetchItems(listId: listId).count, 1, "sofort sichtbar")

        online = true
        await sut.resumeSync()
        XCTAssertEqual(spy.sentItems.map(\.name), ["Brot"])
        XCTAssertEqual(queue.count, 0)
    }

    func test_connectionLost_doesNotCountAsFailure() async throws {
        spy.nextError = URLError(.notConnectedToInternet)
        await sut.createItem(item("Eier"))

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.failedCount, 0)
        XCTAssertEqual(queue.peek().first?.retryCount, 0)

        await sut.resumeSync()
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(try entity(named: "Eier").syncStatus, .synced)
    }

    func test_transientServerError_neverGivesUp() async throws {
        let response = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        await sut.createItem(item("Käse"))              // erster Versuch klappt
        for _ in 0..<10 {
            spy.nextError = HTTPError(data: Data(), response: response)
            await sut.updateItem(try entity(named: "Käse").toItemModel())
            queue.resetRetryDelays()
        }
        XCTAssertEqual(queue.failedCount, 0, "5xx ist vorübergehend: nie endgültig fehlgeschlagen")
        await sut.resumeSync()
        XCTAssertEqual(queue.count, 0)
    }

    // MARK: - Warteschlange zusammenfassen

    func test_offlineEdits_areCoalesced_lastStateWins() async throws {
        online = false
        await sut.createItem(item("Äpfel", units: 1))
        let created = try entity(named: "Äpfel").toItemModel()
        var two = created; two.units = 2
        await sut.updateItem(two)
        var three = created; three.units = 3
        await sut.updateItem(three)

        XCTAssertEqual(queue.count, 1, "höchstens eine Operation je Artikel")
        online = true
        await sut.resumeSync()
        XCTAssertEqual(spy.sentItems.map(\.units), [3])
    }

    func test_createThenDeleteOffline_sendsOnlyTombstone() async throws {
        online = false
        await sut.createItem(item("Brot"))
        await sut.deleteItem(try entity(named: "Brot").toItemModel())
        XCTAssertEqual(queue.count, 1)
        XCTAssertTrue(try itemStore.fetchItems(listId: listId).isEmpty)

        online = true
        await sut.resumeSync()
        XCTAssertEqual(spy.sentItems.count, 1)
        XCTAssertEqual(spy.sentItems.first?.tombstone, true, "Anlage wird nicht mehr gesendet, nur die Löschung")
    }

    func test_overtakenOperation_isDroppedWithoutSending() async throws {
        online = false
        await sut.createItem(item("Tee", units: 2))
        let local = try entity(named: "Tee").toItemModel()
        var newerRemote = local
        newerRemote.units = 7
        newerRemote.hlcTimestamp = (local.hlcTimestamp ?? 0) + 10_000
        newerRemote.hlcNodeId = "other"
        XCTAssertEqual(try itemStore.mergeRemote(newerRemote), .applied)

        online = true
        await sut.resumeSync()
        XCTAssertTrue(spy.calls.isEmpty, "überholte Operation wird nicht gesendet")
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(try entity(named: "Tee").units, 7)
    }

    // MARK: - Server-Antworten

    func test_staleResponse_appliesNewerServerRow() async throws {
        spy.responder = { request in
            var server = request.item
            server.units = 42
            server.hlcTimestamp = (request.item.hlcTimestamp ?? 0) + 5_000
            server.hlcNodeId = "other"
            return ItemUpsertResult(id: request.item.id, status: .stale, item: server, message: nil)
        }
        await sut.createItem(item("Butter"))

        XCTAssertEqual(try entity(named: "Butter").units, 42)
        XCTAssertEqual(try entity(named: "Butter").syncStatus, .synced)
        XCTAssertEqual(queue.count, 0)
    }

    func test_deniedResponse_marksFailed_andEmitsEvent() async throws {
        spy.responder = { ItemUpsertResult(id: $0.item.id, status: .denied, item: nil, message: nil) }
        await sut.createItem(item("Salz"))

        XCTAssertEqual(try entity(named: "Salz").syncStatus, .failed)
        XCTAssertEqual(queue.failedCount, 1)
        XCTAssertTrue(events.contains { if case .itemFailed(let i) = $0 { return i.name == "Salz" } else { return false } })
    }

    func test_retryItem_resendsFailedItem() async throws {
        spy.responder = { ItemUpsertResult(id: $0.item.id, status: .denied, item: nil, message: nil) }
        await sut.createItem(item("Salz"))
        spy.responder = { ItemUpsertResult(id: $0.item.id, status: .applied, item: $0.item, message: nil) }

        await sut.retryItem(try entity(named: "Salz").toItemModel())

        XCTAssertEqual(try entity(named: "Salz").syncStatus, .synced)
        XCTAssertEqual(queue.failedCount, 0)
    }

    // MARK: - Gebündelt, Foto

    func test_applyLocalChanges_sendsOneBatch() async throws {
        online = false
        for name in ["A", "B", "C"] { await sut.createItem(item(name)) }
        online = true
        await sut.resumeSync()
        spy.calls = []

        let checked = try itemStore.fetchItems(listId: listId).map { entity -> ItemModel in
            var m = entity.toItemModel(); m.isChecked = true; return m
        }
        await sut.applyLocalChanges(checked)

        XCTAssertEqual(spy.calls.count, 1, "ein Server-Aufruf für alle")
        XCTAssertEqual(spy.calls.first?.count, 3)
        XCTAssertTrue(try itemStore.fetchItems(listId: listId).allSatisfy { $0.isChecked && $0.syncStatus == .synced })
    }

    func test_imageIsSentOnlyWhenChanged() async throws {
        await sut.createItem(item("Foto", image: "abc"))
        XCTAssertEqual(spy.calls.last?.first?.includeImage, true)

        var edit = try entity(named: "Foto").toItemModel()
        edit.units = 2
        await sut.updateItem(edit)
        XCTAssertEqual(spy.calls.last?.first?.includeImage, false)

        edit.imageData = "xyz"
        await sut.updateItem(edit)
        XCTAssertEqual(spy.calls.last?.first?.includeImage, true)
    }

    // MARK: - Abmelden

    func test_resetForSignOut_clearsQueue() async throws {
        online = false
        await sut.createItem(item("Privat"))
        XCTAssertEqual(queue.count, 1)
        sut.resetForSignOut()
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(queue.failedCount, 0)
    }
}
