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
 - FAM-68: Added test_toItemModel_includesCRDTFields (mapping gap fix).
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

    // MARK: - FAM-XX: Synced-tombstone guard — Re-Add nach bestätigter Remote-Löschung

    /// AC: Entity mit syncStatus=.synced + tombstone=true darf durch apply() NICHT reaktiviert werden.
    func test_apply_syncedTombstone_doesNotReactivateItem() {
        // Given: Item wurde remote gelöscht und Löschung ist lokal bestätigt
        let deletionDate = Date(timeIntervalSinceNow: -60)
        let entity = makeEntity(syncStatus: .synced)
        entity.tombstone = true
        entity.deletedAt = deletionDate
        let originalName = entity.name

        // When: Re-Add landet via deterministischer UUID auf derselben Entity
        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)
        entity.apply(model: model)

        // Then: Entity darf nicht reaktiviert werden
        XCTAssertEqual(entity.deletedAt, deletionDate, "apply() darf deletedAt für synced+tombstone Entities nicht löschen")
        XCTAssertEqual(entity.tombstone, true, "tombstone muss true bleiben")
        XCTAssertEqual(entity.syncStatus, .synced, "syncStatus darf nicht verändert werden")
        XCTAssertEqual(entity.name, originalName, "Felder dürfen nicht überschrieben werden")
    }

    /// AC: Mehrere apply()-Aufrufe reaktivieren eine synced-tombstone Entity nicht kumulativ.
    func test_apply_syncedTombstone_multipleSnapshots_itemRemainsDeleted() {
        // Given
        let deletionDate = Date(timeIntervalSinceNow: -120)
        let entity = makeEntity(syncStatus: .synced)
        entity.tombstone = true
        entity.deletedAt = deletionDate

        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)

        // When: wiederholte upsert()-Aufrufe
        entity.apply(model: model)
        entity.apply(model: model)
        entity.apply(model: model)

        // Then: weiterhin gelöscht
        XCTAssertNotNil(entity.deletedAt, "Entity muss nach mehrfachem apply() gelöscht bleiben")
        XCTAssertEqual(entity.tombstone, true)
        XCTAssertEqual(entity.syncStatus, .synced)
    }

    /// AC: Normales apply() auf aktive (nicht tombstoned) Entity bleibt weiterhin funktional.
    func test_apply_activeSyncedEntity_updatesNormally() {
        // Given: aktives Item ohne Tombstone
        let entity = makeEntity(syncStatus: .synced)
        entity.tombstone = false
        entity.deletedAt = nil

        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)

        // When
        entity.apply(model: model)

        // Then: Felder wurden aktualisiert
        XCTAssertEqual(entity.name, "Milch Updated", "apply() muss bei aktiven Entities Felder aktualisieren")
        XCTAssertNil(entity.deletedAt)
        XCTAssertEqual(entity.syncStatus, .synced)
    }

    /// AC: Bestehender pendingDelete-Guard bleibt durch den neuen Guard unverändert wirksam.
    func test_apply_pendingDelete_guardRemainsEffective_afterNewGuard() {
        // Given: Item lokal zum Löschen vorgemerkt, Bestätigung vom Server noch ausstehend
        let deletionDate = Date(timeIntervalSinceNow: -10)
        let entity = makeEntity(syncStatus: .pendingDelete)
        entity.tombstone = nil  // tombstone noch nicht gesetzt (nur lokal pending)
        entity.deletedAt = deletionDate
        let originalName = entity.name

        // When: Realtime-Snapshot des noch-aktiven Server-Zustands trifft ein
        let model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)
        entity.apply(model: model)

        // Then: pendingDelete-Guard schützt weiterhin
        XCTAssertEqual(entity.deletedAt, deletionDate, "pendingDelete-Guard muss weiterhin greifen")
        XCTAssertEqual(entity.syncStatus, .pendingDelete)
        XCTAssertEqual(entity.name, originalName)
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

    // MARK: - FAM-68: toItemModel() must include CRDT fields

    func test_toItemModel_includesCRDTFields() {
        // Given: entity with all CRDT fields populated
        let entity = makeEntity()
        entity.hlcTimestamp = 999_000
        entity.hlcCounter = 3
        entity.hlcNodeId = "device-abc"
        entity.tombstone = true
        entity.lastModifiedBy = "user-xyz"

        // When
        let model = entity.toItemModel()

        // Then: all CRDT fields must round-trip through toItemModel()
        XCTAssertEqual(model.hlcTimestamp, 999_000, "hlcTimestamp must be included in toItemModel()")
        XCTAssertEqual(model.hlcCounter, 3, "hlcCounter must be included in toItemModel()")
        XCTAssertEqual(model.hlcNodeId, "device-abc", "hlcNodeId must be included in toItemModel()")
        XCTAssertEqual(model.tombstone, true, "tombstone must be included in toItemModel()")
        XCTAssertEqual(model.lastModifiedBy, "user-xyz", "lastModifiedBy must be included in toItemModel()")
    }

    func test_toItemModel_nilCRDTFields_propagateAsNil() {
        // Given: entity without CRDT fields (backward-compat scenario)
        let entity = makeEntity()
        entity.hlcTimestamp = nil
        entity.hlcCounter = nil
        entity.hlcNodeId = nil
        entity.tombstone = nil
        entity.lastModifiedBy = nil

        // When
        let model = entity.toItemModel()

        // Then: nil fields must not be fabricated
        XCTAssertNil(model.hlcTimestamp)
        XCTAssertNil(model.hlcCounter)
        XCTAssertNil(model.hlcNodeId)
        XCTAssertNil(model.tombstone)
        XCTAssertNil(model.lastModifiedBy)
    }
}
