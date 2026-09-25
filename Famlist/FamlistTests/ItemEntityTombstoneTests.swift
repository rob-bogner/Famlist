/*
 ItemEntityTombstoneTests.swift
 FamlistTests
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression tests for FAM-69: Soft-Delete Tombstone semantics.
 - Ältere Stände holen gelöschte Artikel nie zurück (Abgleich per HLC in mergeRemote);
   neuere Stände (erneutes Anlegen) schon. `setSyncStatus(.synced)` löscht `deletedAt` nicht.

 📝 Last Change:
 - Sonderregeln aus apply() in die HLC-Regel verlagert; Tests entsprechend (Audit 25.09.2026).
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

    /// Gelöschter Artikel mit HLC 2000; der Abgleich läuft wie in der App über mergeRemote (ItemSyncPolicy).
    private func mergeOlderSnapshot(into entity: ItemEntity, times: Int = 1) throws {
        let store = SwiftDataItemStore(context: context)
        var model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)
        model.hlcTimestamp = 1_000; model.hlcCounter = 0; model.hlcNodeId = "remote"
        for _ in 0..<times { XCTAssertEqual(try store.mergeRemote(model), .ignored) }
    }

    private func markDeleted(_ entity: ItemEntity, status: ItemEntity.SyncStatus, at date: Date) {
        entity.hlcTimestamp = 2_000; entity.hlcCounter = 0; entity.hlcNodeId = "local"
        entity.tombstone = true
        entity.deletedAt = date
        entity.syncStatus = status
    }

    /// Ein älterer Server-Stand (noch nicht gelöscht) darf eine ausstehende Löschung nicht zurückholen.
    func test_olderSnapshot_doesNotResurrectPendingDelete() throws {
        let entity = makeEntity(syncStatus: .pendingDelete)
        let deletionDate = Date(timeIntervalSinceNow: -5)
        markDeleted(entity, status: .pendingDelete, at: deletionDate)
        try mergeOlderSnapshot(into: entity)
        XCTAssertEqual(entity.deletedAt, deletionDate)
        XCTAssertEqual(entity.syncStatus, .pendingDelete)
        XCTAssertEqual(entity.name, "Milch")
    }

    func test_olderSnapshots_repeatedly_pendingDeleteStaysDeleted() throws {
        let entity = makeEntity(syncStatus: .pendingDelete)
        markDeleted(entity, status: .pendingDelete, at: Date())
        try mergeOlderSnapshot(into: entity, times: 3)
        XCTAssertNotNil(entity.deletedAt)
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

    /// Eine bestätigte Löschung bleibt, wenn später ein älterer Stand eintrifft.
    func test_olderSnapshot_doesNotReactivateSyncedTombstone() throws {
        let deletionDate = Date(timeIntervalSinceNow: -60)
        let entity = makeEntity(syncStatus: .synced)
        markDeleted(entity, status: .synced, at: deletionDate)
        try mergeOlderSnapshot(into: entity)
        XCTAssertEqual(entity.deletedAt, deletionDate)
        XCTAssertEqual(entity.tombstone, true)
        XCTAssertEqual(entity.name, "Milch")
    }

    func test_olderSnapshots_repeatedly_syncedTombstoneStaysDeleted() throws {
        let entity = makeEntity(syncStatus: .synced)
        markDeleted(entity, status: .synced, at: Date(timeIntervalSinceNow: -120))
        try mergeOlderSnapshot(into: entity, times: 3)
        XCTAssertNotNil(entity.deletedAt)
        XCTAssertEqual(entity.tombstone, true)
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

    /// Ein NEUERER Stand (jemand hat den Artikel danach wieder angelegt) gewinnt dagegen – wie auf dem Server.
    func test_newerSnapshot_revivesTombstone() throws {
        let entity = makeEntity(syncStatus: .synced)
        markDeleted(entity, status: .synced, at: Date())
        var model = makeModel(id: entity.id.uuidString, listId: entity.listId.uuidString)
        model.hlcTimestamp = 3_000; model.hlcCounter = 0; model.hlcNodeId = "remote"; model.tombstone = false
        XCTAssertEqual(try SwiftDataItemStore(context: context).mergeRemote(model), .applied)
        XCTAssertNil(entity.deletedAt)
        XCTAssertEqual(entity.tombstone, false)
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
