/*
 RealtimeEventProcessorPendingGuardTests.swift
 FamlistTests
 Created on: 18.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression tests for two bugs in RealtimeEventProcessor.processUpdate():
   1. Missing pending-status guard: a Realtime UPDATE echo must not overwrite an
      entity that has .pendingUpdate or .pendingCreate (in-flight local mutation).
   2. HLC null-timestamp fallback: a Supabase payload with null hlc_timestamp must
      always lose CRDT resolution against any valid local HLC (epoch=0 fallback).

 📝 Last Change:
 - FAM-XX: Initial creation.
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
    hlcTimestamp: Int64? = 9_999_999_999_999,  // very high → would win if not guarded
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

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!
    private var itemStore: SwiftDataItemStore!
    private var sut: RealtimeEventProcessor!

    private let listId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        itemStore = SwiftDataItemStore(context: context)
        sut = RealtimeEventProcessor(
            conflictResolver: ConflictResolver(),
            itemStore: itemStore
        )
    }

    override func tearDown() async throws {
        sut = nil
        itemStore = nil
        context = nil
        container = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func insertEntity(
        id: UUID,
        units: Int,
        syncStatus: ItemEntity.SyncStatus,
        hlcTimestamp: Int64 = 1_000
    ) throws -> ItemEntity {
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
            syncStatus: syncStatus
        )
        entity.hlcTimestamp = hlcTimestamp
        entity.hlcCounter   = 0
        entity.hlcNodeId    = "local-node"
        context.insert(entity)
        try context.save()
        return entity
    }

    // MARK: - Pending Guard: .pendingUpdate must not be overwritten

    /// AC: A Realtime UPDATE echo with a very high HLC must NOT overwrite an entity
    /// that has .pendingUpdate (in-flight local mutation).
    /// Without the guard, units=3 (local) was replaced with units=1 (remote echo).
    func test_processUpdate_pendingUpdate_isNotOverwrittenByRealtimeEcho() async throws {
        // Given: local entity with .pendingUpdate, units=3 (user just incremented)
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .pendingUpdate, hlcTimestamp: 5_000)

        // Remote echo carries units=1 with a higher HLC (would normally win CRDT)
        let payload = makeUpdatePayload(
            id: itemId, listId: listId, units: 1, hlcTimestamp: 9_999_999_999_999
        )

        // When
        await sut.processUpdate(payload, listId: listId)

        // Then: entity must still have units=3
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after processUpdate()")
        }
        XCTAssertEqual(entity.units, 3,
                       ".pendingUpdate entity must not be overwritten by Realtime echo regardless of HLC")
        XCTAssertEqual(entity.syncStatus, .pendingUpdate,
                       "syncStatus must remain .pendingUpdate")
    }

    // MARK: - Pending Guard: .pendingCreate must not be overwritten

    /// AC: A Realtime INSERT/UPDATE echo must NOT overwrite a .pendingCreate entity.
    func test_processUpdate_pendingCreate_isNotOverwrittenByRealtimeEcho() async throws {
        // Given: local entity with .pendingCreate, units=2
        let itemId = UUID()
        try insertEntity(id: itemId, units: 2, syncStatus: .pendingCreate, hlcTimestamp: 5_000)

        // Remote carries units=1 with a very high HLC
        let payload = makeUpdatePayload(
            id: itemId, listId: listId, units: 1, hlcTimestamp: 9_999_999_999_999
        )

        // When
        await sut.processUpdate(payload, listId: listId)

        // Then: entity must still have units=2
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after processUpdate()")
        }
        XCTAssertEqual(entity.units, 2,
                       ".pendingCreate entity must not be overwritten by Realtime echo")
        XCTAssertEqual(entity.syncStatus, .pendingCreate,
                       "syncStatus must remain .pendingCreate")
    }

    // MARK: - .synced entity IS updated by a later remote HLC

    /// AC: A .synced entity must still be updated when the remote HLC is newer.
    func test_processUpdate_syncedEntity_isUpdatedWhenRemoteHLCIsNewer() async throws {
        // Given: .synced entity with units=1, local HLC=1000
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced, hlcTimestamp: 1_000)

        // Remote carries units=5, newer HLC
        let payload = makeUpdatePayload(
            id: itemId, listId: listId, units: 5, hlcTimestamp: 2_000
        )

        // When
        await sut.processUpdate(payload, listId: listId)

        // Then: entity must have units=5
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after processUpdate()")
        }
        XCTAssertEqual(entity.units, 5,
                       ".synced entity must be updated when remote HLC is newer")
    }

    // MARK: - HLC null fallback: epoch=0 always loses

    /// AC: When a Supabase Realtime payload has NO hlc_timestamp field (null),
    /// parseItemFromPayload() must treat it as epoch=0, which always loses to any
    /// valid local HLC.  The previous fallback used current-time ms which could
    /// TIE with or beat the freshly-generated local HLC, causing stale echoes to win.
    func test_processUpdate_nullHlcTimestamp_losesToAnyValidLocalHLC() async throws {
        // Given: .synced entity with a modest local HLC (1_000 ms > epoch 0)
        let itemId = UUID()
        try insertEntity(id: itemId, units: 3, syncStatus: .synced, hlcTimestamp: 1_000)

        // Remote payload with NO hlc_timestamp key (simulates null in Supabase)
        let payload = makeUpdatePayload(
            id: itemId, listId: listId, units: 1, hlcTimestamp: nil  // key omitted
        )

        // When
        await sut.processUpdate(payload, listId: listId)

        // Then: local value must win — remote epoch=0 < local hlc=1000
        guard let entity = try itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after processUpdate()")
        }
        XCTAssertEqual(entity.units, 3,
                       "Remote payload with null hlcTimestamp (epoch=0) must lose CRDT resolution — local units must be preserved")
    }

    // MARK: - Tombstone path is unaffected by the pending guard

    /// AC: A Realtime UPDATE with tombstone=true on a .synced entity must still purge the item.
    /// The pending guard must not block the tombstone path (it returns early before the guard).
    func test_processUpdate_tombstone_syncedEntity_isPurged() async throws {
        // Given: .synced entity
        let itemId = UUID()
        try insertEntity(id: itemId, units: 1, syncStatus: .synced, hlcTimestamp: 1_000)

        // Remote tombstone with newer HLC
        let payload = makeUpdatePayload(
            id: itemId, listId: listId, units: 1, hlcTimestamp: 2_000, tombstone: true
        )

        // When
        await sut.processUpdate(payload, listId: listId)

        // Then: entity must be purged
        let entity = try? itemStore.fetchItem(id: itemId)
        XCTAssertNil(entity, "Tombstone on .synced entity must purge the local record")
    }
}
