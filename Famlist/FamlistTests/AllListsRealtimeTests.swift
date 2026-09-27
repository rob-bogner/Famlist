/*
 AllListsRealtimeTests.swift
 FamlistTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Alle Listen synchron (Watch-Plan Phase 3):
   - Repository: Ein Ereignis einer NICHT beobachteten Liste landet in SwiftData und wird gemeldet;
     ein Echo mit gleicher HLC wird nicht gemeldet; Kanäle leben, solange Liste beobachtet ODER synchron.
   - ListViewModel: hält die Kanäle aller Listen im Vordergrund offen, schließt sie im Hintergrund,
     holt nach einer Wiederverbindung einer anderen Liste deren Delta in SwiftData.

 🔰 Notes for Beginners:
 - Der Realtime-Client zeigt auf eine nicht erreichbare Adresse: Kanäle werden angelegt, verbinden aber nie.
   Geprüft wird nur die Buchführung der Kanäle, nicht der Server.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 3).
 ------------------------------------------------------------------------
 */

import Supabase
import SwiftData
import XCTest
@testable import Famlist

/// Client ohne Server: Realtime zeigt auf 127.0.0.1:9 (kein Dienst), Abfragen werden nicht benutzt.
private final class UnreachableClient: SupabaseClienting, @unchecked Sendable {
    private let client = SupabaseClient(supabaseURL: URL(string: "http://127.0.0.1:9")!, supabaseKey: "test",
                                        options: .init(auth: .init(storage: InMemoryAuthStorage())))
    var auth: any AuthClienting { client.auth }
    var realtime: RealtimeClientV2 { client.realtimeV2 }
    func from(_ table: String) -> PostgrestQueryBuilder { client.from(table) }
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {}
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String { "" }
}

private final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private var values: [String: Data] = [:]
    private let lock = NSLock()
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

/// Repository-Spion: merkt sich die synchronen Listen und liefert je Liste vorbereitete Delta-Zeilen.
@MainActor
private final class SyncSpyRepository: ItemsRepository {
    private(set) var syncedSets: [Set<UUID>] = []
    private(set) var deltaRequests: [UUID] = []
    var deltas: [UUID: [ItemModel]] = [:]
    private(set) var reconnectHandler: (@MainActor (UUID) -> Void)?

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { AsyncStream { _ in } }
    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] { [] }
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        deltaRequests.append(listId)
        return deltas[listId] ?? []
    }
    func keepListsInSync(_ listIds: Set<UUID>) { syncedSets.append(listIds) }
    func setReconnectHandler(_ handler: @escaping @MainActor (UUID) -> Void) { reconnectHandler = handler }
}

@MainActor
final class AllListsRealtimeTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataItemStore!
    private let listA = UUID(), listB = UUID(), listC = UUID()

    override func setUp() async throws {
        container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = SwiftDataItemStore(context: ModelContext(container))
    }

    override func tearDown() async throws {
        for list in [listA, listB, listC] {
            UserDefaults.standard.removeObject(forKey: "fam24_last_sync_ts_\(list.uuidString)")
        }
    }

    private func record(id: UUID, list: UUID, name: String, hlc: Int64) -> [String: Any] {
        ["record": ["id": id.uuidString.lowercased(), "list_id": list.uuidString.lowercased(), "name": name,
                    "units": 1, "measure": "", "price": 0.0, "isChecked": false, "tombstone": false,
                    "hlc_timestamp": hlc, "hlc_counter": 0, "hlc_node_id": "other-device"] as [String: Any]]
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<300 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    private func list(_ id: UUID, _ title: String) -> ListModel {
        ListModel(id: id, ownerId: UUID(), title: title, isDefault: false, createdAt: Date(), updatedAt: Date())
    }

    // MARK: - Repository

    func test_eventOfUnobservedList_landsInSwiftData_andIsReported() async throws {
        let repo = SupabaseItemsRepository(client: UnreachableClient(), itemStore: store)
        var reports: [(UUID, Set<String>)] = []
        repo.setRemoteChangeHandler { list, ids in reports.append((list, ids)) }
        let itemId = UUID()

        await repo.processRealtimeEvent(.insert(payload: record(id: itemId, list: listB, name: "Milch", hlc: 2_000)), listId: listB)

        XCTAssertEqual(try store.fetchItem(id: itemId)?.name, "Milch", "Änderung der nicht geöffneten Liste gespeichert")
        await waitUntil { !reports.isEmpty }
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.0, listB)
        XCTAssertEqual(reports.first?.1, [itemId.uuidString], "gebündelt gemeldet, ID wie in SwiftData")
    }

    func test_echoWithSameHLC_isNotReportedAgain() async throws {
        let repo = SupabaseItemsRepository(client: UnreachableClient(), itemStore: store)
        var reports = 0
        repo.setRemoteChangeHandler { _, _ in reports += 1 }
        let event = RealtimeEvent.update(payload: record(id: UUID(), list: listB, name: "Brot", hlc: 3_000))

        await repo.processRealtimeEvent(event, listId: listB)
        await waitUntil { reports == 1 }
        await repo.processRealtimeEvent(event, listId: listB)          // Echo: gleiche HLC
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(reports, 1, "Echo ändert nichts und wird nicht als fremde Änderung gemeldet")
    }

    func test_channelLivesWhileObservedOrSynced() async throws {
        let repo = SupabaseItemsRepository(client: UnreachableClient(), itemStore: store)
        repo.keepListsInSync([listA, listB])
        XCTAssertEqual(repo.subscribedListIds, [listA, listB])

        let observation = Task { for await _ in repo.observeItems(listId: listA) {} }
        try await Task.sleep(nanoseconds: 50_000_000)
        repo.keepListsInSync([listC])
        XCTAssertEqual(repo.subscribedListIds, [listA, listC], "A bleibt (beobachtet), B zu, C neu")

        observation.cancel()
        await waitUntil { repo.subscribedListIds == [self.listC] }
        XCTAssertEqual(repo.subscribedListIds, [listC], "Beobachtung beendet und nicht synchron → Kanal zu")

        repo.keepListsInSync([])
        XCTAssertTrue(repo.subscribedListIds.isEmpty)
    }

    func test_multiListDelta_defaultAsksEachList() async throws {
        let spy = SyncSpyRepository()
        spy.deltas = [listA: [ItemModel(name: "A")], listB: [ItemModel(name: "B")]]
        let rows = try await spy.fetchItemsSince(listIds: [listA, listB], since: .distantPast)
        XCTAssertEqual(rows.map(\.name), ["A", "B"])
        XCTAssertEqual(spy.deltaRequests, [listA, listB])
    }

    // MARK: - ListViewModel

    private func makeViewModel(_ repo: SyncSpyRepository) -> ListViewModel {
        let context = ModelContext(container)
        let vm = ListViewModel(listId: listA, repository: repo, itemStore: SwiftDataItemStore(context: context),
                               listStore: SwiftDataListStore(context: context), startImmediately: false)
        vm.allLists = [list(listA, "Einkauf"), list(listB, "Drogerie"), list(listC, "Baumarkt")]
        return vm
    }

    func test_foregroundKeepsAllListsInSync_backgroundStops_listChangesFollow() {
        let repo = SyncSpyRepository()
        let vm = makeViewModel(repo)
        XCTAssertTrue(repo.syncedSets.isEmpty, "vor startObserving keine Kanäle")

        vm.startObserving()
        XCTAssertEqual(repo.syncedSets.last, [listA, listB, listC])

        vm.allLists.removeAll { $0.id == self.listC }                       // Liste gelöscht / Zugriff entzogen
        XCTAssertEqual(repo.syncedSets.last, [listA, listB])

        vm.handleAppDidEnterBackground()
        XCTAssertEqual(repo.syncedSets.last, [], "im Hintergrund keine Kanäle")
        let callsInBackground = repo.syncedSets.count
        vm.allLists.append(list(listC, "Baumarkt"))
        XCTAssertEqual(repo.syncedSets.count, callsInBackground, "im Hintergrund keine neuen Kanäle")
    }

    func test_signOut_closesAllChannels() {
        let repo = SyncSpyRepository()
        let vm = makeViewModel(repo)
        vm.startObserving()
        vm.clearForSignOut()
        XCTAssertEqual(repo.syncedSets.last, [])
        XCTAssertFalse(vm.isAllListsSyncActive)
    }

    func test_resubscribeOfOtherList_mergesItsDeltaIntoSwiftData() async throws {
        let repo = SyncSpyRepository()
        let vm = makeViewModel(repo)
        let itemId = UUID()
        let updated = Date(timeIntervalSince1970: 1_790_000_000)
        repo.deltas[listB] = [ItemModel(id: itemId.uuidString, name: "Zahnpasta", units: 2, measure: "",
                                        listId: listB.uuidString, updatedAt: updated,
                                        hlcTimestamp: 5_000, hlcCounter: 0, hlcNodeId: "other-device")]
        vm.startObserving()

        repo.reconnectHandler?(listB)
        await waitUntil { (try? self.store.fetchItem(id: itemId)) != nil && vm.listItemCounts[self.listB] == 1 }

        XCTAssertEqual(try store.fetchItem(id: itemId)?.units, 2, "Delta der nicht geöffneten Liste übernommen")
        XCTAssertEqual(vm.listItemCounts[listB], 1, "Zähler in „Meine Listen“ aktualisiert")
        XCTAssertEqual(vm.loadLastSyncTimestamp(for: listB), updated, "Zeitmarke der Liste B vorgerückt")
        XCTAssertFalse(vm.items.contains { $0.id == itemId.uuidString }, "geöffnete Liste A unverändert")
    }

    func test_backgroundDelta_ignoredAfterAccessLoss() async throws {
        let repo = SyncSpyRepository()
        let vm = makeViewModel(repo)
        let itemId = UUID()
        repo.deltas[listC] = [ItemModel(id: itemId.uuidString, name: "Schrauben", units: 1, measure: "",
                                        listId: listC.uuidString, hlcTimestamp: 5_000, hlcCounter: 0,
                                        hlcNodeId: "other-device")]
        vm.startObserving()
        vm.allLists.removeAll { $0.id == self.listC }
        await vm.syncListInBackground(listC)
        XCTAssertNil(try store.fetchItem(id: itemId), "Liste ohne Zugriff wird nicht wieder befüllt")
    }

    func test_syncedLists_cappedBelowChannelLimit_activeListIncluded() {
        let repo = SyncSpyRepository()
        let vm = makeViewModel(repo)
        vm.allLists = (0..<120).map { list(UUID(), "Liste \($0)") }
        vm.startObserving()
        let synced = repo.syncedSets.last ?? []
        XCTAssertEqual(synced.count, ListViewModel.maxSyncedLists)
        XCTAssertTrue(synced.contains(listA), "geöffnete Liste immer dabei")
    }
}
