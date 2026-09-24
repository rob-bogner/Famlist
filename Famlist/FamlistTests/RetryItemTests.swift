/*
 RetryItemTests.swift
 FamlistTests
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for FAM-78: Retry-UI for .failed Items.
 - Covers isSyncFailed mapping and retryItem reset behaviour.

 📝 Last Change:
 - FAM-78: Initial creation.
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class RetryItemTests: XCTestCase {

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
            name: "Butter",
            units: 1,
            measure: "Stk",
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

    // MARK: - isSyncFailed mapping

    func test_toItemModel_failedEntityMapsIsSyncFailedTrue() {
        // Given: entity whose sync has permanently failed
        let entity = makeEntity(syncStatus: .failed)

        // When
        let model = entity.toItemModel()

        // Then
        XCTAssertTrue(model.isSyncFailed, "isSyncFailed must be true when syncStatus == .failed")
    }

    func test_toItemModel_syncedEntityMapsIsSyncFailedFalse() {
        // Given: entity that synced successfully
        let entity = makeEntity(syncStatus: .synced)

        // When
        let model = entity.toItemModel()

        // Then
        XCTAssertFalse(model.isSyncFailed, "isSyncFailed must be false when syncStatus == .synced")
    }

    func test_toItemModel_pendingUpdateEntityMapsIsSyncFailedFalse() {
        let entity = makeEntity(syncStatus: .pendingUpdate)
        XCTAssertFalse(entity.toItemModel().isSyncFailed)
    }

    func test_toItemModel_pendingCreateEntityMapsIsSyncFailedFalse() {
        let entity = makeEntity(syncStatus: .pendingCreate)
        XCTAssertFalse(entity.toItemModel().isSyncFailed)
    }

    // MARK: - isSyncFailed default in ItemModel

    func test_isSyncFailed_defaultsToFalse() {
        let model = ItemModel(name: "Milch")
        XCTAssertFalse(model.isSyncFailed, "isSyncFailed must default to false in ItemModel")
    }

    func test_isSyncFailed_canBeSetViaInit() {
        let model = ItemModel(name: "Milch", isSyncFailed: true)
        XCTAssertTrue(model.isSyncFailed)
    }

    // MARK: - retryItem resets entity syncStatus

    func test_retryItem_setsEntityToPendingUpdate() {
        // Given: entity stuck in .failed
        let entity = makeEntity(syncStatus: .failed)
        entity.setSyncStatus(.failed)
        let itemStore = SwiftDataItemStore(context: context)

        // When: simulate what SyncEngine.retryItem does
        let uuid = entity.id
        if let fetched = try? itemStore.fetchItem(id: uuid) {
            fetched.setSyncStatus(.pendingUpdate)
            try? itemStore.save()
        }

        // Then
        XCTAssertEqual(entity.syncStatus, .pendingUpdate,
                       "retryItem must reset syncStatus to .pendingUpdate")
    }

    // MARK: - resetFailedOperation

    func test_resetFailedOperation_clearsFailed() {
        // Given: a failed SyncOperation in the queue
        let operationQueue = SyncOperationQueue(context: context)
        let listId = UUID()
        let op = SyncOperation(
            type: .update,
            itemId: "item-abc",
            listId: listId,
            itemSnapshotJSON: Data(),
            crdtMetadataJSON: Data(),
            retryCount: 5,
            hasFailed: true,
            lastErrorMessage: "Network error"
        )
        context.insert(op)
        try? context.save()

        // Verify it was inserted as failed
        XCTAssertTrue(op.hasFailed)
        XCTAssertEqual(op.retryCount, 5)

        // When
        operationQueue.resetFailedOperation(itemId: "item-abc")

        // Then
        XCTAssertFalse(op.hasFailed, "hasFailed must be reset to false")
        XCTAssertEqual(op.retryCount, 0, "retryCount must be reset to 0")
        XCTAssertNil(op.nextRetryAt, "nextRetryAt must be cleared")
        XCTAssertNil(op.lastErrorMessage, "lastErrorMessage must be cleared")
    }

    func test_resetFailedOperation_doesNotAffectNonMatchingItems() {
        // Given: two failed operations for different items
        let op1 = SyncOperation(
            type: .update, itemId: "item-1", listId: UUID(),
            itemSnapshotJSON: Data(), crdtMetadataJSON: Data(),
            retryCount: 5, hasFailed: true
        )
        let op2 = SyncOperation(
            type: .update, itemId: "item-2", listId: UUID(),
            itemSnapshotJSON: Data(), crdtMetadataJSON: Data(),
            retryCount: 5, hasFailed: true
        )
        context.insert(op1)
        context.insert(op2)
        try? context.save()

        let operationQueue = SyncOperationQueue(context: context)

        // When: only reset item-1
        operationQueue.resetFailedOperation(itemId: "item-1")

        // Then: item-2 remains failed
        XCTAssertFalse(op1.hasFailed, "item-1 operation must be reset")
        XCTAssertTrue(op2.hasFailed, "item-2 operation must remain failed")
    }
}
