/*
 IncrementalSyncPendingGuardTests.swift
 FamlistTests
 Created on: 18.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression tests for the runIncrementalSync() pending-status guard.
 - Covers the bug where a stale remote delta (e.g. units=1 from Supabase)
   overwrote an in-flight local mutation (.pendingUpdate units=2), causing
   refreshItemsFromStore() to present the stale lower value in the UI.

 📝 Last Change:
 - Schutz jetzt über die HLC (ItemSyncPolicy) statt über den Sync-Status: Die lokale Änderung ist neuer
   (höhere HLC) und bleibt; eine NEUERE Remote-Änderung gewinnt dagegen (Audit 25.09.2026).
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Configurable Repository Spy

/// Lets tests control what fetchItemsSince() returns.
@MainActor
private final class StubItemsRepository: ItemsRepository {

    /// Items to return from the next fetchItemsSince() call.
    var deltaItems: [ItemModel] = []

    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        return deltaItems
    }

    // Unused protocol stubs
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { AsyncStream { _ in } }
    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] { [] }
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }
}

// MARK: - Tests

@MainActor
final class IncrementalSyncPendingGuardTests: XCTestCase {

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!
    private var itemStore: SwiftDataItemStore!
    private var stub: StubItemsRepository!
    private var sut: ListViewModel!

    private let listId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        itemStore = SwiftDataItemStore(context: context)
        stub = StubItemsRepository()
        sut = ListViewModel(
            listId: listId,
            repository: stub,
            itemStore: itemStore,
            listStore: SwiftDataListStore(context: context),
            startImmediately: false
        )
    }

    override func tearDown() async throws {
        sut = nil
        stub = nil
        itemStore = nil
        context = nil
        container = nil
    }

    // MARK: - Helpers

    /// Inserts an entity into SwiftData with the given syncStatus and units.
    @discardableResult
    private func insertEntity(id: UUID, units: Int, syncStatus: ItemEntity.SyncStatus,
                              hlcTimestamp: Int64 = 2_000) throws -> ItemEntity {
        let entity = ItemEntity(
            id: id,
            listId: listId,
            ownerPublicId: nil,
            imageData: nil,
            name: "Tee",
            units: units,
            measure: "pkg",
            price: 0,
            isChecked: false,
            category: nil,
            productDescription: nil,
            brand: nil,
            syncStatus: syncStatus,
            hlcTimestamp: hlcTimestamp,
            hlcCounter: 0,
            hlcNodeId: "local"
        )
        context.insert(entity)
        try context.save()
        return entity
    }

    /// Builds a delta ItemModel for the given id with the given units and a future updatedAt.
    /// Standard-HLC 1000 = älter als die lokale Zeile (2000): der typische veraltete Server-Stand.
    private func makeDeltaItem(id: UUID, units: Int, hlcTimestamp: Int64 = 1_000) -> ItemModel {
        var item = ItemModel(
            id: id.uuidString,
            name: "Tee",
            units: units,
            listId: listId.uuidString,
            hlcTimestamp: hlcTimestamp,
            hlcCounter: 0,
            hlcNodeId: "remote"
        )
        item.updatedAt = Date(timeIntervalSinceNow: 60)  // future → passes the since-filter
        return item
    }

    // MARK: - AC 1: .pendingUpdate entity must NOT be overwritten by stale delta

    /// AC: When a local entity has .pendingUpdate (units=2) and a delta arrives with
    /// units=1 (stale Supabase value), runIncrementalSync() must skip the upsert so
    /// that SwiftData still contains units=2 after the sync.
    func test_runIncrementalSync_pendingUpdate_doesNotOverwriteLocalChange() async throws {
        // Given: entity with .pendingUpdate, units=2 (in-flight increment)
        let itemId = UUID()
        try insertEntity(id: itemId, units: 2, syncStatus: .pendingUpdate)

        // Delta from Supabase still has stale units=1
        stub.deltaItems = [makeDeltaItem(id: itemId, units: 1)]

        // When
        await sut.runIncrementalSync()

        // Then: entity must still have units=2
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after runIncrementalSync()")
        }
        XCTAssertEqual(entity.units, 2,
                       ".pendingUpdate entity must not be overwritten by stale remote delta")
        XCTAssertEqual(entity.syncStatus, .pendingUpdate,
                       "syncStatus must remain .pendingUpdate")
    }

    // MARK: - AC 2: .pendingCreate entity must NOT be overwritten

    /// AC: Same protection for .pendingCreate — the item was re-added locally and
    /// units=1 in the delta must not reset units back.
    func test_runIncrementalSync_pendingCreate_doesNotOverwriteLocalChange() async throws {
        // Given: entity with .pendingCreate, units=3
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .pendingCreate)

        stub.deltaItems = [makeDeltaItem(id: itemId, units: 1)]

        // When
        await sut.runIncrementalSync()

        // Then: entity must still have units=3
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after runIncrementalSync()")
        }
        XCTAssertEqual(entity.units, 3,
                       ".pendingCreate entity must not be overwritten by remote delta")
        XCTAssertEqual(entity.syncStatus, .pendingCreate,
                       "syncStatus must remain .pendingCreate")
    }

    // MARK: - AC 3: .synced entity IS updated by the delta

    /// AC: When an entity is .synced (no pending local mutation), runIncrementalSync()
    /// must apply the delta as usual so remote updates are reflected in the UI.
    func test_runIncrementalSync_syncedEntity_isUpdatedByDelta() async throws {
        // Given: entity with .synced, units=1
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced)

        // Delta brings units=5 from another device (neuere HLC)
        stub.deltaItems = [makeDeltaItem(id: itemId, units: 5, hlcTimestamp: 3_000)]

        // When
        await sut.runIncrementalSync()

        // Then: entity must have units=5
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after runIncrementalSync()")
        }
        XCTAssertEqual(entity.units, 5,
                       ".synced entity must be updated by the remote delta")
    }

    // MARK: - AC 4: items view model reflects correct units after guard triggers

    /// AC: After a guarded runIncrementalSync(), sut.items must show units=2 — not units=1.
    func test_runIncrementalSync_pendingUpdate_itemsShowLocalUnits() async throws {
        // Given: entity with .pendingUpdate, units=2; also in sut.items
        let itemId = UUID()
        try insertEntity(id: itemId, units: 2, syncStatus: .pendingUpdate)
        sut.refreshItemsFromStore()  // load into sut.items

        stub.deltaItems = [makeDeltaItem(id: itemId, units: 1)]

        // When
        await sut.runIncrementalSync()

        // Then: published items must still have units=2
        XCTAssertEqual(sut.items.first?.units, 2,
                       "sut.items must reflect local units=2, not stale remote units=1")
    }

    // MARK: - AC 5: neuere Remote-Änderung gewinnt auch gegen eine ältere ausstehende lokale

    /// Last-Writer-Wins wie auf dem Server: Die lokale Änderung (HLC 2000) ist älter als die des anderen
    /// Geräts (HLC 3000). Die Remote-Zeile gewinnt, und die SyncEngine sendet die überholte Operation nicht mehr.
    func test_runIncrementalSync_newerRemote_winsOverOlderPendingLocal() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 2, syncStatus: .pendingUpdate, hlcTimestamp: 2_000)
        stub.deltaItems = [makeDeltaItem(id: itemId, units: 7, hlcTimestamp: 3_000)]

        await sut.runIncrementalSync()

        let entity = try XCTUnwrap(itemStore.fetchItem(id: itemId))
        XCTAssertEqual(entity.units, 7)
        XCTAssertEqual(entity.syncStatus, .synced)
    }

    // MARK: - AC 6: Löschmarkierung im Delta blendet aus, ohne die Zeile zu entfernen

    func test_runIncrementalSync_remoteTombstone_hidesItem_andKeepsTombstone() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced, hlcTimestamp: 1_000)
        var tomb = makeDeltaItem(id: itemId, units: 1, hlcTimestamp: 5_000)
        tomb.tombstone = true
        stub.deltaItems = [tomb]

        await sut.runIncrementalSync()

        XCTAssertTrue(sut.items.isEmpty)
        let entity = try XCTUnwrap(itemStore.fetchItem(id: itemId), "Löschmarkierung bleibt lokal erhalten")
        XCTAssertEqual(entity.tombstone, true)

        // Ein später eintreffendes, ÄLTERES Update darf den Artikel nicht zurückholen.
        stub.deltaItems = [makeDeltaItem(id: itemId, units: 9, hlcTimestamp: 4_000)]
        await sut.runIncrementalSync()
        XCTAssertTrue(sut.items.isEmpty)
    }
}
