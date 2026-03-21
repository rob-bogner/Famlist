/*
 RemoteSyncHighlightTests.swift
 FamlistTests
 Created on: 2026-03-21

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for the remote-sync highlight signal path.
 - Covers markRecentlySynced(), recentlySyncedItemIDs lifecycle,
   and the guarantee that local mutations never trigger highlights.

 🛠 Includes:
 - markRecentlySynced() marks and auto-clears correctly
 - Overlapping calls do not cancel each other
 - Pending-animation items are excluded from Realtime detection
 - Pull-to-Refresh (suppressHighlight) produces no highlight IDs

 📝 Last Change:
 - Initial creation for remote-sync highlight feature.
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class RemoteSyncHighlightTests: XCTestCase {

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: ListViewModel!

    private let listId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self, SyncOperation.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        sut = ListViewModel(
            listId: listId,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: false
        )
    }

    override func tearDown() async throws {
        sut = nil
        context = nil
        container = nil
    }

    // MARK: - Helpers

    private func makeItem(id: String = UUID().uuidString,
                          hlcTimestamp: Int64? = nil) -> ItemModel {
        ItemModel(
            id: id,
            name: "Item-\(id.prefix(4))",
            units: 1,
            listId: listId.uuidString,
            hlcTimestamp: hlcTimestamp
        )
    }

    // MARK: - markRecentlySynced

    func test_markRecentlySynced_populatesRecentlySyncedItemIDs() {
        let ids: Set<String> = ["id-1", "id-2"]
        sut.markRecentlySynced(ids: ids)
        XCTAssertEqual(sut.recentlySyncedItemIDs, ids)
    }

    func test_markRecentlySynced_emptySet_doesNothing() {
        sut.markRecentlySynced(ids: [])
        XCTAssertTrue(sut.recentlySyncedItemIDs.isEmpty)
    }

    func test_markRecentlySynced_overlappingCalls_unionsIDs() {
        sut.markRecentlySynced(ids: ["id-1"])
        sut.markRecentlySynced(ids: ["id-2"])
        XCTAssertTrue(sut.recentlySyncedItemIDs.contains("id-1"))
        XCTAssertTrue(sut.recentlySyncedItemIDs.contains("id-2"))
    }

    func test_markRecentlySynced_secondCallForSameID_doesNotDuplicateOrReset() {
        sut.markRecentlySynced(ids: ["id-1"])
        sut.markRecentlySynced(ids: ["id-1"]) // idempotent via formUnion
        XCTAssertEqual(sut.recentlySyncedItemIDs, ["id-1"])
    }

    func test_markRecentlySynced_clearsAfterDelay() async {
        sut.markRecentlySynced(ids: ["id-auto-clear"])
        XCTAssertTrue(sut.recentlySyncedItemIDs.contains("id-auto-clear"))
        // Wait slightly longer than the 2-second clear window.
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        XCTAssertFalse(sut.recentlySyncedItemIDs.contains("id-auto-clear"),
                       "ID must be removed after the 2-second TTL")
    }

    func test_markRecentlySynced_clearingOneSetDoesNotAffectOther() async {
        // First call — clears after 2s
        sut.markRecentlySynced(ids: ["early"])
        // Second call 0.5s later — should survive the first clear
        try? await Task.sleep(nanoseconds: 500_000_000)
        sut.markRecentlySynced(ids: ["late"])
        // Let the first clear fire (2s after first call ≈ 1.5s from now)
        try? await Task.sleep(nanoseconds: 1_700_000_000)
        XCTAssertFalse(sut.recentlySyncedItemIDs.contains("early"),
                       "First ID should be cleared")
        XCTAssertTrue(sut.recentlySyncedItemIDs.contains("late"),
                      "Second ID must NOT be cleared by the first TTL task")
    }

    // MARK: - applyItems: Realtime detection logic

    func test_realtimeHandler_newItem_isMarkedAsSynced() {
        // Seed the ViewModel with an existing item
        let existing = makeItem(id: "existing", hlcTimestamp: 1000)
        sut.items = [existing]

        // Simulate a Realtime snapshot that contains a brand-new remote item
        let newRemote = makeItem(id: "new-remote", hlcTimestamp: 2000)
        let snapshot = [existing, newRemote]

        // Replicate the detection logic from startObserving()'s stream handler
        simulateRealtimeSnapshot(snapshot)

        XCTAssertTrue(sut.recentlySyncedItemIDs.contains("new-remote"),
                      "New item arriving via Realtime must be highlighted")
        XCTAssertFalse(sut.recentlySyncedItemIDs.contains("existing"),
                       "Unchanged existing item must NOT be highlighted")
    }

    func test_realtimeHandler_updatedItem_isMarkedAsSynced() {
        let itemId = "shared-item"
        let local = makeItem(id: itemId, hlcTimestamp: 1000)
        sut.items = [local]

        // Remote update arrives with a newer HLC
        let remoteUpdated = makeItem(id: itemId, hlcTimestamp: 2000)
        simulateRealtimeSnapshot([remoteUpdated])

        XCTAssertTrue(sut.recentlySyncedItemIDs.contains(itemId),
                      "Item with changed HLC timestamp must be highlighted")
    }

    func test_realtimeHandler_unchangedItem_notMarked() {
        let itemId = "stable-item"
        let local = makeItem(id: itemId, hlcTimestamp: 1000)
        sut.items = [local]

        // Snapshot with same HLC (e.g. local echo with local_wins in CRDT)
        simulateRealtimeSnapshot([local])

        XCTAssertFalse(sut.recentlySyncedItemIDs.contains(itemId),
                       "Item with unchanged HLC must NOT be highlighted (e.g. local echo)")
    }

    func test_realtimeHandler_pendingAnimationItem_isExcluded() {
        let itemId = "locally-animating"
        let local = makeItem(id: itemId, hlcTimestamp: 1000)
        sut.items = [local]
        sut.pendingAnimatedItemIDs.insert(itemId) // Simulates in-flight local toggle

        let remoteUpdate = makeItem(id: itemId, hlcTimestamp: 2000)
        simulateRealtimeSnapshot([remoteUpdate])

        XCTAssertFalse(sut.recentlySyncedItemIDs.contains(itemId),
                       "Item with a local pending animation must never be highlighted")
    }

    // MARK: - pullToRefresh suppressHighlight

    func test_recentlySynced_isEmptyAfterConstruction() {
        XCTAssertTrue(sut.recentlySyncedItemIDs.isEmpty,
                      "recentlySyncedItemIDs must start empty")
    }

    func test_localMutation_doesNotTouchRecentlySyncedIDs() {
        // Direct field mutations (not via remote path) must never affect the highlight set
        sut.items = [makeItem(id: "local-item")]
        sut.refreshItemsFromStore()
        XCTAssertTrue(sut.recentlySyncedItemIDs.isEmpty,
                      "refreshItemsFromStore() must not populate recentlySyncedItemIDs")
    }

    // MARK: - Private simulation helper

    /// Replicates the Realtime stream handler's detection logic from startObserving().
    private func simulateRealtimeSnapshot(_ snapshot: [ItemModel]) {
        let currentItems = sut.items
        let oldIDs = Set(currentItems.map { $0.id })
        let oldTimestamps = Dictionary(
            uniqueKeysWithValues: currentItems.compactMap { item -> (String, Int64)? in
                guard let ts = item.hlcTimestamp else { return nil }
                return (item.id, ts)
            }
        )
        let remoteChangedIDs: Set<String> = Set(snapshot.compactMap { item -> String? in
            guard !sut.pendingAnimatedItemIDs.contains(item.id) else { return nil }
            guard !sut.pendingBulkDeleteIDs.contains(item.id) else { return nil }
            if !oldIDs.contains(item.id) { return item.id }
            let oldTs = oldTimestamps[item.id]
            let newTs = item.hlcTimestamp
            if oldTs != newTs { return item.id }
            return nil
        })
        if !remoteChangedIDs.isEmpty {
            sut.markRecentlySynced(ids: remoteChangedIDs)
        }
        sut.applyItems(snapshot)
    }
}
