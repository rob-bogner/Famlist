/*
 SyncEngineReactivationTests.swift
 FamlistTests
 Created on: 18.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression tests for FAM-XX: Re-Add Bug nach Tombstone-Deletion.
 - Covers two targeted fixes in SyncEngine:
   1. processOperation(.create) must enrich the item snapshot with CRDT metadata
      so tombstone=false and a valid HLC reach Supabase (not nil via encodeIfPresent).
   2. storeLocally() must treat a re-add of a soft-deleted entity as pendingCreate
      (clearing deletedAt) instead of pendingUpdate (leaving deletedAt set).

 📝 Last Change:
 - FAM-XX: Initial creation.
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Spy Repository

/// Captures items passed to createItem() / updateItem() without touching Supabase.
@MainActor
private final class SpyItemsRepository: ItemsRepository {

    var createdItems: [ItemModel] = []
    var updatedItems: [ItemModel] = []

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        createdItems.append(item)
        return item
    }

    func updateItem(_ item: ItemModel) async throws {
        updatedItems.append(item)
    }

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        AsyncStream { _ in }
    }

    func deleteItem(id: String, listId: UUID) async throws {}

    func bulkToggleItems(_ items: [ItemModel], listId: UUID) async throws {}

    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }

    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] { [] }
}

// MARK: - Tests

@MainActor
final class SyncEngineReactivationTests: XCTestCase {

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!
    private var spy: SpyItemsRepository!
    private var itemStore: SwiftDataItemStore!
    private var sut: SyncEngine!

    override func setUp() async throws {
        container = PersistenceController(inMemory: true).container
        context = container.mainContext
        spy = SpyItemsRepository()
        itemStore = SwiftDataItemStore(context: context)
        let queue = SyncOperationQueue(context: context)
        sut = SyncEngine(
            repository: spy,
            itemStore: itemStore,
            operationQueue: queue,
            conflictResolver: ConflictResolver(),
            hlcGenerator: HybridLogicalClockGenerator(nodeId: "test-node")
        )
    }

    override func tearDown() async throws {
        sut = nil
        spy = nil
        itemStore = nil
        container = nil
        context = nil
    }

    // MARK: - Helpers

    /// Inserts a confirmed-tombstoned entity (simulates item that was deleted and sync'd).
    private func insertTombstonedEntity(listId: UUID, name: String, hlcTimestamp: Int64 = 1_000) -> ItemEntity {
        let itemId = UUID.deterministicItemID(listId: listId, name: name)
        let entity = ItemEntity(
            id: itemId,
            listId: listId,
            ownerPublicId: nil,
            imageData: nil,
            name: name,
            units: 1,
            measure: "l",
            price: 0,
            isChecked: false,
            category: nil,
            productDescription: nil,
            brand: nil,
            syncStatus: .synced
        )
        entity.tombstone = true
        entity.deletedAt = Date(timeIntervalSinceNow: -60)
        entity.hlcTimestamp = hlcTimestamp
        entity.hlcCounter = 0
        entity.hlcNodeId = "other-node"
        context.insert(entity)
        try? context.save()
        return entity
    }

    // MARK: - Fix 1: processOperation(.create) sends explicit tombstone=false

    /// AC: A fresh createItem() must send tombstone=false (not nil) to the repository.
    /// Without this fix tombstone=nil causes encodeIfPresent to omit the field, leaving
    /// any existing DB tombstone=true intact after the Supabase upsert.
    func test_createItem_sendsExplicitTombstoneFalse() async {
        // Given: brand-new item from the UI (tombstone=nil)
        let listId = UUID()
        let item = ItemModel(name: "Milch", listId: listId.uuidString)

        // When
        await sut.createItem(item)

        // Then: repository must receive tombstone=false (not nil)
        XCTAssertEqual(spy.createdItems.count, 1, "createItem must reach the repository")
        XCTAssertEqual(spy.createdItems.first?.tombstone, false,
                       "createItem must send tombstone=false — nil would leave an existing DB tombstone intact")
    }

    /// AC: A fresh createItem() must send a valid HLC timestamp to the repository.
    /// Without this the encodeIfPresent omits hlc_timestamp and the DB keeps the old
    /// deletion HLC, which weakens the HLC-based conflict resolution.
    func test_createItem_sendsValidHLCFromMetadata() async {
        // Given: brand-new item (no prior HLC)
        let listId = UUID()
        let item = ItemModel(name: "Milch", listId: listId.uuidString)

        // When
        await sut.createItem(item)

        // Then: all three HLC fields must be non-nil
        guard let sent = spy.createdItems.first else {
            return XCTFail("repository.createItem() was not called")
        }
        XCTAssertNotNil(sent.hlcTimestamp,  "hlcTimestamp must come from CRDT metadata, not be nil")
        XCTAssertNotNil(sent.hlcCounter,    "hlcCounter must come from CRDT metadata, not be nil")
        XCTAssertNotNil(sent.hlcNodeId,     "hlcNodeId must come from CRDT metadata, not be nil")
    }

    /// AC: Re-add of a tombstoned item sends tombstone=false (not nil, not true).
    /// This is the primary fix for the Supabase upsert — the DB must overwrite
    /// tombstone=true with tombstone=false on the conflicting row.
    func test_reAdd_afterConfirmedDelete_sendsExplicitTombstoneFalseToRepository() async {
        // Given: confirmed-tombstoned entity (simulates item that was deleted + sync confirmed)
        let listId = UUID()
        insertTombstonedEntity(listId: listId, name: "Milch", hlcTimestamp: 1_000)

        // When: user re-adds the same item (deterministic UUID collides with tombstoned entity)
        let item = ItemModel(name: "Milch", listId: listId.uuidString)
        await sut.createItem(item)

        // Then: repository must receive tombstone=false so the DB clears the tombstone
        XCTAssertEqual(spy.createdItems.count, 1)
        XCTAssertEqual(spy.createdItems.first?.tombstone, false,
                       "Re-add must send tombstone=false — never nil or true — to clear the DB tombstone row")
    }

    /// AC: Re-add sends a newer HLC than the tombstone's HLC.
    func test_reAdd_sendsNewerHLCThanTombstone() async {
        // Given: tombstone with old HLC (timestamp=1000)
        let listId = UUID()
        insertTombstonedEntity(listId: listId, name: "Milch", hlcTimestamp: 1_000)

        // When
        let item = ItemModel(name: "Milch", listId: listId.uuidString)
        await sut.createItem(item)

        // Then: sent HLC must be newer than the tombstone's HLC (ensures local wins in conflict resolution)
        guard let sentTimestamp = spy.createdItems.first?.hlcTimestamp else {
            return XCTFail("hlcTimestamp must not be nil in the sent item")
        }
        XCTAssertGreaterThan(sentTimestamp, 1_000,
                             "New HLC must be newer than the tombstone HLC so applyRemoteTombstone local-wins if needed")
    }

    // MARK: - Fix 2: storeLocally() reactivation — deletedAt cleared, item visible

    /// AC: After re-adding a confirmed-tombstoned item, deletedAt must be nil.
    /// Without this fix storeLocally() sets .pendingUpdate which does not clear deletedAt,
    /// leaving the item invisible in the UI even though it was re-added.
    func test_reAdd_afterConfirmedDelete_clearsDeletedAt() async {
        // Given: confirmed-tombstoned entity
        let listId = UUID()
        let itemId = UUID.deterministicItemID(listId: listId, name: "Milch")
        insertTombstonedEntity(listId: listId, name: "Milch")

        // When
        let item = ItemModel(name: "Milch", listId: listId.uuidString)
        await sut.createItem(item)

        // Then: deletedAt must be nil — item is visible
        guard let entity = try? itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after re-add")
        }
        XCTAssertNil(entity.deletedAt,
                     "deletedAt must be nil after re-add — otherwise the item stays invisible in the UI")
    }

    /// AC: After re-adding a confirmed-tombstoned item, tombstone must be false on the entity.
    func test_reAdd_afterConfirmedDelete_setsTombstoneFalseLocally() async {
        // Given
        let listId = UUID()
        let itemId = UUID.deterministicItemID(listId: listId, name: "Milch")
        insertTombstonedEntity(listId: listId, name: "Milch")

        // When
        let item = ItemModel(name: "Milch", listId: listId.uuidString)
        await sut.createItem(item)

        // Then
        guard let entity = try? itemStore.fetchItem(id: itemId) else {
            return XCTFail("Entity must still exist after re-add")
        }
        XCTAssertEqual(entity.tombstone, false,
                       "tombstone must be false on the local entity after re-add")
    }

    // MARK: - Fix 3: processOperation(.update) sends new HLC from metadata

    /// AC: updateItem() must send a new HLC timestamp to the repository — not the old
    /// HLC that was baked into the item snapshot when the operation was queued.
    /// Without this fix Supabase stores an outdated HLC which can cause cross-device
    /// conflict resolution to mis-fire (old HLC loses against the tombstone HLC it should beat).
    func test_updateItem_sendsNewHLCFromMetadata() async {
        // Given: existing entity with a known old HLC
        let listId = UUID()
        let entity = ItemEntity(
            id: UUID(),
            listId: listId,
            ownerPublicId: nil,
            imageData: nil,
            name: "Tee",
            units: 1,
            measure: "pkg",
            price: 0,
            isChecked: false,
            category: nil,
            productDescription: nil,
            brand: nil,
            syncStatus: .synced
        )
        let oldTimestamp: Int64 = 1_000
        entity.hlcTimestamp = oldTimestamp
        entity.hlcCounter   = 0
        entity.hlcNodeId    = "old-node"
        context.insert(entity)
        try? context.save()

        // When: updateItem() is called (simulates duplicate-add increment)
        var updatedItem = ItemModel(
            id: entity.id.uuidString,
            name: "Tee",
            units: 2,
            listId: listId.uuidString
        )
        updatedItem.hlcTimestamp = oldTimestamp  // item carries old HLC at queue time
        await sut.updateItem(updatedItem)

        // Then: repository must receive a timestamp strictly newer than the old HLC
        guard let sent = spy.updatedItems.first else {
            return XCTFail("repository.updateItem() was not called")
        }
        XCTAssertNotNil(sent.hlcTimestamp,  "hlcTimestamp must not be nil in the sent item")
        XCTAssertNotNil(sent.hlcCounter,    "hlcCounter must not be nil in the sent item")
        XCTAssertNotNil(sent.hlcNodeId,     "hlcNodeId must not be nil in the sent item")
        XCTAssertGreaterThan(sent.hlcTimestamp ?? 0, oldTimestamp,
                             "updateItem() must send a new HLC — not the stale HLC from the queued snapshot")
    }

    /// AC: updateItem() sends units=2 (correct field value) to the repository.
    func test_updateItem_sendsCorrectFieldValues() async {
        // Given: existing entity
        let listId = UUID()
        let entity = ItemEntity(
            id: UUID(),
            listId: listId,
            ownerPublicId: nil,
            imageData: nil,
            name: "Tee",
            units: 1,
            measure: "pkg",
            price: 0,
            isChecked: false,
            category: nil,
            productDescription: nil,
            brand: nil,
            syncStatus: .synced
        )
        entity.hlcTimestamp = 1_000
        entity.hlcCounter   = 0
        entity.hlcNodeId    = "old-node"
        context.insert(entity)
        try? context.save()

        // When
        let updatedItem = ItemModel(id: entity.id.uuidString, name: "Tee", units: 2, listId: listId.uuidString)
        await sut.updateItem(updatedItem)

        // Then: name and units must match what was passed in
        XCTAssertEqual(spy.updatedItems.first?.name,  "Tee")
        XCTAssertEqual(spy.updatedItems.first?.units, 2)
    }

    // MARK: - Normal create path — unaffected by fixes

    /// AC: A normal createItem() with no prior deletion still reaches the repository.
    func test_createItem_normalNew_reachesRepository() async {
        // Given: no prior entity
        let listId = UUID()
        let item = ItemModel(name: "Butter", listId: listId.uuidString)

        // When
        await sut.createItem(item)

        // Then
        XCTAssertEqual(spy.createdItems.count, 1, "Normal createItem must reach the repository")
        XCTAssertEqual(spy.createdItems.first?.name, "Butter")
    }

    /// AC: A normal createItem() does not accidentally set deletedAt on the new entity.
    func test_createItem_normalNew_doesNotSetDeletedAt() async {
        // Given: no prior entity
        let listId = UUID()
        let item = ItemModel(name: "Butter", listId: listId.uuidString)
        let deterministicId = UUID.deterministicItemID(listId: listId, name: "Butter")

        // When
        await sut.createItem(item)

        // Then
        guard let entity = try? itemStore.fetchItem(id: deterministicId) else {
            return XCTFail("Entity must be created")
        }
        XCTAssertNil(entity.deletedAt, "Normal createItem must not set deletedAt")
    }
}
