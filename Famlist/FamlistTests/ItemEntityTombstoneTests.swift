/*
 ItemEntityTombstoneTests.swift
 FamlistTests
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression tests for FAM-69: Soft-Delete Tombstone semantics.
 - Ensures `apply(model:)` never resurrects locally-deleted items
   and `setSyncStatus(.synced)` never clears `deletedAt`.

 📝 Last Change:
 - Initial creation for FAM-69 regression coverage.
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ItemEntityTombstoneTests: XCTestCase {

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = PersistenceController(inMemory: true).container
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeEntity(syncStatus: ItemEntity.SyncStatus = .synced) -> ItemEntity {
        let entity = ItemEntity(
            id: UUID(),
            listId: UUID(),
            ownerPublicId: nil,
            imageData: nil,
            name: "Milch",
            units: 1,
            measure: "l",
            price: 0,
            isChecked: false,
            category: nil,
            productDescription: nil,
            brand: nil,
            syncStatus: syncStatus
        )
        context.insert(entity)
        return entity
    }

    private func makeModel(id: String, listId: String) -> ItemModel {
        ItemModel(id: id, name: "Milch Updated", listId: listId)
    }

    // MARK: - AC 1: setSyncStatus(.synced) does not modify deletedAt

    func test_setSyncStatus_synced_doesNotClearDeletedAt() {
        // Given: item that is soft-deleted
        let entity = makeEntity()
        let deletionDate = Date()
        entity.deletedAt = deletionDate

        // When: we mark as synced (e.g. after unrelated update)
        entity.setSyncStatus(.synced)

        // Then: deletedAt must remain untouched
        XCTAssertEqual(entity.deletedAt, deletionDate, "setSyncStatus(.synced) must not clear deletedAt")
    }

    // MARK: - AC 2: pendingDelete items survive a Realtime snapshot (apply guard)

    func test_apply_pendingDelete_doesNotResurrectItem() {
        // Given: item is in pendingDelete state with a tombstone timestamp
        let entity = makeEntity(syncStatus: .pendingDelete)
        let deletionDate = Date(timeIntervalSinceNow: -5)
        entity.deletedAt = deletionDate
        let originalName = entity.name

        // When: a Realtime snapshot arrives with the (still-live) server version
        let remoteModel = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)
        entity.apply(model: remoteModel)

        // Then: deletedAt and syncStatus must be unchanged — item stays hidden
        XCTAssertEqual(entity.deletedAt, deletionDate, "apply() must not clear deletedAt for pendingDelete items")
        XCTAssertEqual(entity.syncStatus, .pendingDelete, "syncStatus must remain pendingDelete")
        XCTAssertEqual(entity.name, originalName, "no field should be overwritten for a pendingDelete item")
    }

    func test_apply_pendingDelete_multipleSnapshots_itemRemainsDeleted() {
        // Given: item pendingDelete
        let entity = makeEntity(syncStatus: .pendingDelete)
        entity.deletedAt = Date()

        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)

        // When: multiple snapshots arrive before the delete is confirmed
        entity.apply(model: model)
        entity.apply(model: model)
        entity.apply(model: model)

        // Then: still deleted
        XCTAssertNotNil(entity.deletedAt, "item must remain soft-deleted across multiple snapshots")
        XCTAssertEqual(entity.syncStatus, .pendingDelete)
    }

    // MARK: - AC 2: non-deleted items ARE updated by apply()

    func test_apply_synced_updatesFieldsAndClearsDeletedAt() {
        // Given: a previously soft-deleted item that was restored and is now synced
        let entity = makeEntity(syncStatus: .synced)
        entity.deletedAt = Date() // Hypothetical leftover (should be cleared by apply for synced items)

        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)

        // When: remote snapshot comes in for a live item
        entity.apply(model: model)

        // Then: deletedAt is cleared, name is updated
        XCTAssertNil(entity.deletedAt, "apply() must clear deletedAt for non-pendingDelete items")
        XCTAssertEqual(entity.name, "Milch Updated")
        XCTAssertEqual(entity.syncStatus, .synced)
    }

    func test_apply_pendingUpdate_updatesFieldsAndClearsDeletedAt() {
        // Given: item with a pending update (not a delete)
        let entity = makeEntity(syncStatus: .pendingUpdate)
        entity.deletedAt = nil // Normal live item

        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)

        // When
        entity.apply(model: model)

        // Then: updated normally
        XCTAssertNil(entity.deletedAt)
        XCTAssertEqual(entity.name, "Milch Updated")
    }

    // MARK: - setSyncStatus boundary cases

    func test_setSyncStatus_pendingDelete_setsDeletion() {
        let entity = makeEntity(syncStatus: .synced)
        XCTAssertNil(entity.deletedAt)

        entity.setSyncStatus(.pendingDelete)

        XCTAssertNotNil(entity.deletedAt, "pendingDelete must set deletedAt")
        XCTAssertEqual(entity.syncStatus, .pendingDelete)
    }

    func test_setSyncStatus_pendingRecovery_clearsDeletedAt() {
        let entity = makeEntity(syncStatus: .pendingDelete)
        entity.deletedAt = Date()

        entity.setSyncStatus(.pendingRecovery)

        XCTAssertNil(entity.deletedAt, "pendingRecovery must clear deletedAt (explicit restore path)")
        XCTAssertEqual(entity.syncStatus, .pendingRecovery)
    }
}
