/*
 RealtimeEventProcessorPendingGuardTests.swift
 FamlistTests
 Created on: 18.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Realtime-Ereignisse werden per HLC abgeglichen (ItemSyncPolicy), wie auf dem Server:
   1. Das eigene Echo (gleiche HLC) und ältere Stände ändern nichts – ausstehende Änderungen bleiben.
   2. Neuere Stände anderer Geräte gewinnen, auch gegen ältere ausstehende lokale Änderungen.
   3. Löschmarkierungen blenden aus, bleiben lokal erhalten und schützen vor späten, älteren Updates.
   4. Fehlende HLC im Ereignis (null) verliert immer (Epoche 0).

 📝 Last Change:
 - Auf Last-Writer-Wins umgestellt (Audit 25.09.2026). Vorher verwarf die App auch NEUERE Stände,
   solange eine eigene Änderung ausstand – die Geräte liefen dann dauerhaft auseinander.
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Helpers

/// Builds a Supabase-style Realtime payload for processUpdate().
private func makeUpdatePayload(
    id: UUID,
    listId: UUID,
    name: String = "Tee",
    units: Int = 1,
    hlcTimestamp: Int64? = 9_999_999_999_999,
    hlcCounter: Int = 0,
    hlcNodeId: String = "remote-node",
    tombstone: Bool = false
) -> [String: Any] {
    var record: [String: Any] = [
        "id":        id.uuidString,
        "list_id":   listId.uuidString,
        "name":      name,
        "units":     units,
        "measure":   "pkg",
        "price":     0.0,
        "isChecked": false,
        "tombstone": tombstone,
        "hlc_counter":      hlcCounter,
        "hlc_node_id":      hlcNodeId
    ]
    if let ts = hlcTimestamp {
        record["hlc_timestamp"] = ts
    }
    // Omitting hlc_timestamp key entirely simulates null from Supabase
    return ["record": record]
}

// MARK: - Tests

@MainActor
final class RealtimeEventProcessorPendingGuardTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var itemStore: SwiftDataItemStore!
    private var sut: RealtimeEventProcessor!

    private let listId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = ModelContext(container)
        itemStore = SwiftDataItemStore(context: context)
        sut = RealtimeEventProcessor(itemStore: itemStore)
    }

    override func tearDown() async throws {
        sut = nil
        itemStore = nil
        context = nil
        container = nil
    }

    @discardableResult
    private func insertEntity(id: UUID, units: Int, syncStatus: ItemEntity.SyncStatus,
                              hlcTimestamp: Int64 = 1_000, nodeId: String = "local-node") throws -> ItemEntity {
        let entity = ItemEntity(id: id, listId: listId, ownerPublicId: nil, imageData: nil, name: "Tee",
                                units: units, measure: "pkg", price: 0, isChecked: false, category: nil,
                                productDescription: nil, brand: nil, syncStatus: syncStatus,
                                hlcTimestamp: hlcTimestamp, hlcCounter: 0, hlcNodeId: nodeId)
        context.insert(entity)
        try context.save()
        return entity
    }

    // MARK: - Eigene Echos und ältere Stände

    func test_ownEcho_sameHLC_changesNothing() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .pendingUpdate, hlcTimestamp: 5_000)
        let echo = makeUpdatePayload(id: itemId, listId: listId, units: 3, hlcTimestamp: 5_000, hlcNodeId: "local-node")

        await sut.processUpdate(echo, listId: listId)

        let entity = try XCTUnwrap(itemStore.fetchItem(id: itemId))
        XCTAssertEqual(entity.units, 3)
        XCTAssertEqual(entity.syncStatus, .pendingUpdate, "Bestätigung kommt von der SyncEngine, nicht vom Echo")
    }

    func test_olderRemote_doesNotOverwritePendingLocal() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .pendingUpdate, hlcTimestamp: 5_000)
        let stale = makeUpdatePayload(id: itemId, listId: listId, units: 1, hlcTimestamp: 4_000)

        await sut.processUpdate(stale, listId: listId)

        let entity = try XCTUnwrap(itemStore.fetchItem(id: itemId))
        XCTAssertEqual(entity.units, 3)
        XCTAssertEqual(entity.syncStatus, .pendingUpdate)
    }

    // MARK: - Neuere Stände gewinnen

    func test_newerRemote_winsOverOlderPendingLocal() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .pendingUpdate, hlcTimestamp: 5_000)
        let newer = makeUpdatePayload(id: itemId, listId: listId, units: 8, hlcTimestamp: 6_000)

        await sut.processUpdate(newer, listId: listId)

        let entity = try XCTUnwrap(itemStore.fetchItem(id: itemId))
        XCTAssertEqual(entity.units, 8)
        XCTAssertEqual(entity.syncStatus, .synced)
        XCTAssertEqual(entity.hlcTimestamp, 6_000)
    }

    func test_newerRemote_updatesSyncedEntity() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced, hlcTimestamp: 1_000)

        await sut.processUpdate(makeUpdatePayload(id: itemId, listId: listId, units: 4, hlcTimestamp: 2_000), listId: listId)

        XCTAssertEqual(try XCTUnwrap(itemStore.fetchItem(id: itemId)).units, 4)
    }

    func test_unknownItem_isInserted() async throws {
        let itemId = UUID()
        await sut.processInsertion(makeUpdatePayload(id: itemId, listId: listId, units: 2, hlcTimestamp: 2_000), listId: listId)
        let entity = try XCTUnwrap(itemStore.fetchItem(id: itemId))
        XCTAssertEqual(entity.units, 2)
        XCTAssertEqual(entity.syncStatus, .synced)
    }

    // MARK: - HLC fehlt (null)

    func test_nullRemoteHLC_alwaysLosesAgainstLocal() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .synced, hlcTimestamp: 1)
        let payload = makeUpdatePayload(id: itemId, listId: listId, units: 1, hlcTimestamp: nil)

        await sut.processUpdate(payload, listId: listId)

        XCTAssertEqual(try XCTUnwrap(itemStore.fetchItem(id: itemId)).units, 3)
    }

    // MARK: - Löschmarkierungen

    func test_newerRemoteTombstone_hidesItem_keepsTombstone_andBlocksOlderUpdates() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced, hlcTimestamp: 1_000)

        await sut.processUpdate(makeUpdatePayload(id: itemId, listId: listId, hlcTimestamp: 3_000, tombstone: true),
                                listId: listId)
        XCTAssertTrue(try itemStore.fetchItems(listId: listId).isEmpty, "ausgeblendet")
        XCTAssertEqual(try XCTUnwrap(itemStore.fetchItem(id: itemId)).tombstone, true, "bleibt lokal erhalten")

        await sut.processUpdate(makeUpdatePayload(id: itemId, listId: listId, units: 9, hlcTimestamp: 2_000),
                                listId: listId)
        XCTAssertTrue(try itemStore.fetchItems(listId: listId).isEmpty, "älteres Update holt nicht zurück")
    }

    func test_olderRemoteTombstone_doesNotDeleteNewerLocalReAdd() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 2, syncStatus: .pendingCreate, hlcTimestamp: 5_000)

        await sut.processUpdate(makeUpdatePayload(id: itemId, listId: listId, hlcTimestamp: 4_000, tombstone: true),
                                listId: listId)

        XCTAssertEqual(try itemStore.fetchItems(listId: listId).count, 1)
    }

    func test_newerRemoteReAdd_revivesTombstonedItem() async throws {
        let itemId = UUID()
        let entity = try insertEntity(id: itemId, units: 1, syncStatus: .synced, hlcTimestamp: 1_000)
        entity.setTombstone(true)
        try context.save()

        await sut.processUpdate(makeUpdatePayload(id: itemId, listId: listId, units: 2, hlcTimestamp: 2_000), listId: listId)

        XCTAssertEqual(try itemStore.fetchItems(listId: listId).first?.units, 2)
    }

    // MARK: - DELETE (Zeile auf dem Server endgültig entfernt)

    func test_hardDelete_purgesLocalRow() async throws {
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced)
        await sut.processDeletion(["old_record": ["id": itemId.uuidString]], listId: listId)
        XCTAssertNil(try itemStore.fetchItem(id: itemId))
    }
}
