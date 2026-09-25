/*
 OfflineListsRepositoryTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listen offline zuerst (Audit M3): Aufträge wirken sofort lokal, werden in Reihenfolge nachgesendet,
   Wiederholungen sind unschädlich, verschwundene Listen werden gemeldet, erster Start ohne Netz,
   Artikel warten auf die Anlage ihrer Liste, Abmelden räumt alles auf.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
import Supabase
@testable import Famlist

@MainActor
private final class FakeRemoteLists: ListsRepository {
    var offline = false
    var lists: [ListModel] = []
    var calls: [String] = []
    var nextPermanentError: Error?

    private func check() throws {
        if offline { throw URLError(.notConnectedToInternet) }
        if let error = nextPermanentError { nextPermanentError = nil; throw error }
    }

    func ensureDefaultListExists(for owner: UUID) async throws -> List { throw URLError(.unsupportedURL) }
    func observeLists(for owner: UUID) -> AsyncStream<[List]> { AsyncStream { $0.finish() } }
    func createList(for owner: UUID, title: String) async throws -> List { throw URLError(.unsupportedURL) }
    func createList(id: UUID, for owner: UUID, title: String) async throws -> List {
        try check()
        calls.append("create:\(title)")
        if lists.contains(where: { $0.id == id }) { throw PostgrestError(code: "23505", message: "duplicate") }
        lists.append(ListModel(id: id, ownerId: owner, title: title, isDefault: false, createdAt: Date(), updatedAt: Date()))
        return List(id: id, owner_id: owner, title: title, is_default: false, created_at: Date(), updated_at: Date())
    }
    func ensureDefaultList(id: UUID, for owner: UUID) async throws -> ListModel {
        try check()
        calls.append("ensureDefault")
        if let existing = lists.first(where: { $0.ownerId == owner && $0.isDefault }) { return existing }
        let list = ListModel(id: id, ownerId: owner, title: "My List", isDefault: true, createdAt: Date(), updatedAt: Date())
        lists.append(list)
        return list
    }
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel { try await ensureDefaultList(id: UUID(), for: ownerId) }
    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] { try check(); return lists }
    func renameList(listId: UUID, title: String) async throws -> ListModel {
        try check()
        calls.append("rename:\(title)")
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { throw PostgrestError(code: "PGRST116", message: "none") }
        lists[index] = lists[index].with(title: title)
        return lists[index]
    }
    func deleteList(listId: UUID) async throws { try check(); calls.append("delete"); lists.removeAll { $0.id == listId } }
    func setDefaultList(listId: UUID, ownerId: UUID) async throws { try check(); calls.append("setDefault") }
    func removeMember(listId: UUID, profileId: UUID) async throws { try check(); calls.append("leave") }
    func leaveList(listId: UUID, profileId: UUID) async throws { try await removeMember(listId: listId, profileId: profileId) }
    func fetchMembers(listId: UUID) async throws -> [ListMember] { [] }
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
}

@MainActor
final class OfflineListsRepositoryTests: XCTestCase {
    private var remote: FakeRemoteLists!
    private var sut: OfflineListsRepository!
    private var directory: URL!
    private let owner = UUID()

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lists-\(UUID().uuidString)")
        remote = FakeRemoteLists()
        sut = OfflineListsRepository(remote: remote, store: ListLocalStore(directory: directory))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        sut = nil
        remote = nil
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    func test_offline_create_rename_setDefault_visibleImmediately_thenSentInOrder() async throws {
        remote.offline = true
        let created = try await sut.createList(for: owner, title: "WG")
        _ = try await sut.renameList(listId: created.id, title: "WG Einkauf")
        try await sut.setDefaultList(listId: created.id, ownerId: owner)

        let offlineLists = try await sut.fetchAllLists(for: owner)
        XCTAssertEqual(offlineLists.map(\.title), ["WG Einkauf"])
        XCTAssertEqual(offlineLists.first?.isDefault, true)
        XCTAssertFalse(sut.isListReady(created.id), "Liste noch nicht auf dem Server")
        XCTAssertTrue(remote.calls.isEmpty)

        remote.offline = false
        await sut.flush()
        XCTAssertEqual(remote.calls, ["create:WG", "rename:WG Einkauf", "setDefault"])
        XCTAssertTrue(sut.isListReady(created.id))
        XCTAssertEqual(remote.lists.first?.id, created.id, "Server übernimmt die Geräte-ID")
    }

    func test_createAgainAfterLostAnswer_isTreatedAsSuccess() async throws {
        let id = UUID()
        remote.lists = [ListModel(id: id, ownerId: owner, title: "Schon da", isDefault: false, createdAt: Date(), updatedAt: Date())]
        _ = try await sut.createList(id: id, for: owner, title: "Schon da")
        await sut.flush()
        XCTAssertTrue(sut.store.outbox.isEmpty, "23505 = bereits angelegt, kein Endlos-Wiederholen")
    }

    func test_permanentError_dropsOperation_andContinues() async throws {
        let gone = ListModel(id: UUID(), ownerId: owner, title: "Alt", isDefault: false, createdAt: Date(), updatedAt: Date())
        remote.lists = [gone]
        _ = try await sut.fetchAllLists(for: owner)
        remote.lists = []                                   // auf einem anderen Gerät gelöscht
        remote.offline = true
        _ = try await sut.renameList(listId: gone.id, title: "Weg")
        let created = try await sut.createList(for: owner, title: "Neu")
        remote.offline = false
        await sut.flush()
        XCTAssertTrue(sut.store.outbox.isEmpty)
        XCTAssertTrue(remote.lists.contains { $0.id == created.id })
    }

    func test_vanishedLists_areReported() async throws {
        let shared = ListModel(id: UUID(), ownerId: UUID(), title: "Geteilt", isDefault: false, createdAt: Date(), updatedAt: Date())
        remote.lists = [shared]
        _ = try await sut.fetchAllLists(for: owner)
        var vanished: [UUID] = []
        sut.onListsVanished = { vanished += $0 }
        remote.lists = []                                      // aus der Liste entfernt
        _ = try await sut.fetchAllLists(for: owner)
        XCTAssertEqual(vanished, [shared.id])
    }

    func test_firstStartOffline_createsLocalDefault_sentLaterWithSameId() async throws {
        remote.offline = true
        let local = try await sut.fetchDefaultList(for: owner)
        XCTAssertTrue(local.isDefault)
        XCTAssertFalse(sut.isListReady(local.id))
        remote.offline = false
        await sut.flush()
        XCTAssertEqual(remote.lists.first?.id, local.id)
        XCTAssertTrue(sut.isListReady(local.id))
    }

    func test_offlineRead_returnsCachedLists() async throws {
        remote.lists = [ListModel(id: UUID(), ownerId: owner, title: "Edeka", isDefault: true, createdAt: Date(), updatedAt: Date())]
        _ = try await sut.fetchAllLists(for: owner)
        remote.offline = true
        let cached = try await sut.fetchAllLists(for: owner)
        XCTAssertEqual(cached.map(\.title), ["Edeka"])
        let cachedDefault = try await sut.fetchDefaultList(for: owner)
        XCTAssertEqual(cachedDefault.title, "Edeka")
    }

    func test_clearLocalData_removesCacheAndQueue() async throws {
        remote.offline = true
        _ = try await sut.createList(for: owner, title: "Privat")
        sut.clearLocalData()
        XCTAssertNil(sut.store.lists)
        XCTAssertTrue(sut.store.outbox.isEmpty)
    }

    func test_syncEngine_holdsItemsUntilListExists() async throws {
        let container = PersistenceController(inMemory: true).container
        let store = SwiftDataItemStore(context: container.mainContext)
        let repo = PreviewItemsRepository()
        var ready = false
        let engine = SyncEngine(repository: repo, itemStore: store, operationQueue: SyncOperationQueue(context: container.mainContext),
                                hlcGenerator: HybridLogicalClockGenerator(nodeId: "n"), isListReady: { _ in ready })
        let listId = UUID()
        await engine.createItem(ItemModel(name: "Milch", listId: listId.uuidString))
        XCTAssertEqual(engine.pendingOperations, 1, "wartet auf die Liste")
        ready = true
        await engine.resumeSync()
        XCTAssertEqual(engine.pendingOperations, 0)
    }
}
