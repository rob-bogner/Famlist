/*
 WatchSyncCoordinatorTests.swift
 FamlistWatchTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sync-Knoten der Uhr (WatchSyncCoordinator) ohne Server:
   - Erste Abfrage holt neue Listen komplett, danach nur das Delta seit der Zeitmarke (ein Aufruf).
   - Nicht mehr gelieferte Listen verschwinden samt Artikeln.
   - Artikel vom iPhone nur per HLC; ältere ändern nichts.
   - Abmelden leert Speicher, Warteschlange, Artikelstamm und Merker.
   - Ohne Sitzung wird nichts abgefragt.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftData
import XCTest
@testable import FamlistWatch

/// Artikel-Server: merkt sich jede Delta-Anfrage (Listen, Zeitmarke).
@MainActor
private final class FakeItems: ItemsRepository {
    var rows: [ItemModel] = []
    private(set) var requests: [(lists: [UUID], since: Date)] = []

    func fetchItemsSince(listIds: [UUID], since: Date) async throws -> [ItemModel] {
        requests.append((listIds, since))
        let ids = Set(listIds.map(\.uuidString))
        return rows.filter { ids.contains($0.listId ?? "") && ($0.updatedAt ?? .distantPast) > since }
    }
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        try await fetchItemsSince(listIds: [listId], since: since)
    }
    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] {
        requests.map { ItemUpsertResult(id: $0.item.id, status: .applied, item: $0.item, message: nil) }
    }
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { AsyncStream { _ in } }
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }
}

@MainActor
private final class FakeRemote: WatchRemoteSource {
    var lists: [ListModel] = []
    var favorite: UUID?
    func fetchLists(userId: UUID) async throws -> [ListModel] { lists }
    func fetchFavoriteListId() async throws -> UUID? { favorite }
    func fetchCategories(userId: UUID) async throws -> [CategoryDefinition] { [] }
}

@MainActor
final class WatchSyncCoordinatorTests: XCTestCase {
    private var items: FakeItems!
    private var remote: FakeRemote!
    private var defaults: UserDefaults!
    private var directory: URL!
    private var signedIn: UUID? = UUID()
    private let listA = UUID(), listB = UUID()

    override func setUp() async throws {
        items = FakeItems()
        remote = FakeRemote()
        defaults = UserDefaults(suiteName: "WatchSyncCoordinatorTests.\(UUID().uuidString)")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        remote.lists = [list(listA, "Einkauf"), list(listB, "Drogerie")]
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func list(_ id: UUID, _ title: String) -> ListModel {
        ListModel(id: id, ownerId: UUID(), title: title, isDefault: false, createdAt: Date(), updatedAt: Date())
    }

    private func row(_ list: UUID, _ name: String, units: Double = 1, hlc: Int64, updated: TimeInterval) -> ItemModel {
        ItemModel(id: UUID().uuidString, name: name, units: units, measure: "", listId: list.uuidString,
                  updatedAt: Date(timeIntervalSince1970: updated), hlcTimestamp: hlc, hlcCounter: 0,
                  hlcNodeId: "phone", tombstone: false)
    }

    private func makeSUT() -> WatchSyncCoordinator {
        let catalog = OfflineItemCatalogRepository(remote: PreviewItemCatalogRepository(),
                                                   store: CatalogLocalStore(directory: directory))
        return WatchSyncCoordinator(container: PersistenceController(inMemory: true).container, itemsRepository: items,
                                    remote: remote, catalog: catalog, transport: nil,
                                    hlcGenerator: HybridLogicalClockGenerator(nodeId: "watch-test"),
                                    defaults: defaults, userId: { [unowned self] in self.signedIn })
    }

    func test_firstPull_fetchesNewListsCompletely_thenOnlyDeltaInOneCall() async throws {
        items.rows = [row(listA, "Milch", hlc: 1_000, updated: 1_800_000_000),
                      row(listB, "Zahnpasta", hlc: 1_000, updated: 1_800_000_010)]
        let sut = makeSUT()

        await sut.pull()
        XCTAssertEqual(items.requests.count, 1)
        XCTAssertEqual(items.requests.first?.since, .distantPast, "neue Listen komplett")
        XCTAssertEqual(Set(items.requests.first?.lists ?? []), [listA, listB], "alle Listen in einem Aufruf")
        XCTAssertEqual(try sut.itemStore.fetchItems(listId: listA).map(\.name), ["Milch"])
        XCTAssertEqual(try sut.listStore.fetchLists().count, 2)

        items.rows.append(row(listA, "Brot", hlc: 2_000, updated: 1_800_000_020))
        await sut.pull()
        let delta = try XCTUnwrap(items.requests.last)
        XCTAssertEqual(delta.since, Date(timeIntervalSince1970: 1_800_000_010 - 5), "seit Zeitmarke, 5 s Überlappung")
        XCTAssertEqual(Set(try sut.itemStore.fetchItems(listId: listA).map(\.name)), ["Milch", "Brot"])
    }

    func test_newlySharedList_isFetchedCompletely() async throws {
        remote.lists = [list(listA, "Einkauf")]
        items.rows = [row(listA, "Milch", hlc: 1_000, updated: 1_800_000_000)]
        let sut = makeSUT()
        await sut.pull()

        remote.lists.append(list(listB, "Geteilt"))
        items.rows.append(row(listB, "Alt, aber neu für die Uhr", hlc: 500, updated: 1_700_000_000))
        await sut.pull()
        let fresh = try XCTUnwrap(items.requests.first { $0.lists == [listB] })
        XCTAssertEqual(fresh.since, .distantPast)
        XCTAssertEqual(try sut.itemStore.fetchItems(listId: listB).count, 1)
    }

    func test_listNoLongerDelivered_isRemovedWithItems() async throws {
        items.rows = [row(listB, "Zahnpasta", hlc: 1_000, updated: 1_800_000_000)]
        let sut = makeSUT()
        await sut.pull()
        XCTAssertEqual(try sut.itemStore.fetchItems(listId: listB).count, 1)

        remote.lists = [list(listA, "Einkauf")]                           // Zugriff auf B entzogen
        await sut.pull()
        XCTAssertNil(try sut.listStore.fetchList(id: listB))
        XCTAssertTrue(try sut.itemStore.fetchItems(listId: listB, includeDeleted: true).isEmpty)
    }

    func test_itemsFromPhone_onlyNewerHLC() throws {
        let sut = makeSUT()
        var milk = row(listA, "Milch", units: 1, hlc: 5_000, updated: 1)
        sut.mergeFromPhone([milk])
        let revision = sut.revision
        milk.units = 9
        milk.hlcTimestamp = 4_000
        sut.mergeFromPhone([milk])                                        // älter
        XCTAssertEqual(try sut.itemStore.fetchItem(id: UUID(uuidString: milk.id)!)?.units, 1)
        XCTAssertEqual(sut.revision, revision, "nichts geändert → keine neue Anzeige")
        XCTAssertEqual(sut.engine.operationQueue.count, 0, "nicht erneut senden – das iPhone sendet selbst")
    }

    func test_reset_clearsEverythingOfTheAccount() async throws {
        items.rows = [row(listA, "Milch", hlc: 1_000, updated: 1_800_000_000)]
        remote.favorite = listA
        let sut = makeSUT()
        await sut.pull()
        signedIn = nil
        await sut.engine.createItem(ItemModel(name: "Offline", listId: listA.uuidString))  // wartet (ohne Sitzung)
        XCTAssertEqual(sut.engine.operationQueue.count, 1)

        sut.reset()

        XCTAssertTrue(try sut.listStore.fetchLists().isEmpty)
        XCTAssertTrue(try sut.itemStore.fetchItems(listId: listA, includeDeleted: true).isEmpty)
        XCTAssertEqual(sut.engine.operationQueue.count, 0, "nichts gelangt ins nächste Konto")
        XCTAssertNil(sut.favoriteListId)
        XCTAssertEqual(WatchDeltaMarks(defaults: defaults).since, .distantPast)
        XCTAssertTrue(WatchDeltaMarks(defaults: defaults).knownLists.isEmpty)
    }

    func test_withoutSession_nothingIsFetched() async {
        signedIn = nil
        let sut = makeSUT()
        await sut.pull()
        XCTAssertTrue(items.requests.isEmpty)
    }
}
