/*
 ItemAvailabilityTests.swift
 FamlistTests
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den „Nicht verfügbar“-Status (isUnavailable), die Tab-Filter und
   „Alle abhaken“ pro Kategorie aus dem Hybrid-Redesign.

 🛠 Includes:
 - ItemModel-Decoding ohne isUnavailable-Schlüssel (alte SyncOperation-Snapshots) → false
 - ItemEntity ↔ ItemModel-Mapping überträgt isUnavailable
 - ConflictResolver.resolveFieldLevel übernimmt isUnavailable nur bei neuerem Remote-HLC
 - ListViewModel: toggleItemUnavailable, visibleOpenGroups / visibleCheckedItems, checkAllItems(in:)

 🔰 Notes for Beginners:
 - In-Memory-SwiftData pro Test, `startImmediately: false`, kein Supabase.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ItemAvailabilityTests: XCTestCase {

    private var viewModel: ListViewModel!
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private let listId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        modelContext = ModelContext(modelContainer)
        viewModel = ListViewModel(listId: listId,
                                  repository: PreviewItemsRepository(),
                                  itemStore: SwiftDataItemStore(context: modelContext),
                                  listStore: SwiftDataListStore(context: modelContext),
                                  startImmediately: false)
    }

    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    private func makeItem(_ name: String, category: ItemCategory = .sonstiges,
                          isChecked: Bool = false, isUnavailable: Bool = false) -> ItemModel {
        ItemModel(name: name, units: 1, measure: "piece", isChecked: isChecked, isUnavailable: isUnavailable,
                  category: category.rawValue, listId: listId.uuidString, createdAt: Date(), updatedAt: Date())
    }

    // MARK: - Codable

    func test_decode_withoutIsUnavailableKey_defaultsToFalse() throws {
        let json = #"{"id":"A","name":"Milch","units":1,"measure":"l","price":0,"isChecked":false}"#
        let item = try JSONDecoder().decode(ItemModel.self, from: Data(json.utf8))
        XCTAssertFalse(item.isUnavailable)
        XCTAssertEqual(item.name, "Milch")
    }

    func test_encodeDecode_roundTripKeepsIsUnavailable() throws {
        let original = makeItem("Butter", isUnavailable: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ItemModel.self, from: encoder.encode(original))
        XCTAssertTrue(decoded.isUnavailable)
        XCTAssertEqual(decoded.id, original.id)
    }

    // MARK: - Mapping

    func test_entityMapping_transfersIsUnavailable() {
        let entity = ItemEntity.make(from: makeItem("Butter", isUnavailable: true))
        XCTAssertTrue(entity.isUnavailable)
        XCTAssertTrue(entity.toItemModel().isUnavailable)

        var update = entity.toItemModel()
        update.isUnavailable = false
        entity.apply(model: update)
        XCTAssertFalse(entity.isUnavailable)
    }

    // MARK: - Conflict Resolution (Last-Writer-Wins über die ganze Zeile, ItemSyncPolicy)

    private var itemStore: SwiftDataItemStore { SwiftDataItemStore(context: modelContext) }

    func test_mergeRemote_newerRemoteIsUnavailableWins() throws {
        var local = makeItem("Butter", isUnavailable: false)
        local.hlcTimestamp = 1000; local.hlcCounter = 0; local.hlcNodeId = "a"
        try itemStore.upsert(model: local)
        var remote = local
        remote.isUnavailable = true
        remote.hlcTimestamp = 2000; remote.hlcNodeId = "b"
        XCTAssertEqual(try itemStore.mergeRemote(remote), .applied)
        XCTAssertTrue(try XCTUnwrap(itemStore.fetchItem(id: XCTUnwrap(UUID(uuidString: local.id)))).isUnavailable)
    }

    func test_mergeRemote_olderRemoteIsUnavailableLoses() throws {
        var local = makeItem("Butter", isUnavailable: false)
        local.hlcTimestamp = 3000; local.hlcCounter = 0; local.hlcNodeId = "a"
        try itemStore.upsert(model: local)
        var remote = local
        remote.isUnavailable = true
        remote.hlcTimestamp = 2000; remote.hlcNodeId = "b"
        XCTAssertEqual(try itemStore.mergeRemote(remote), .ignored)
        XCTAssertFalse(try XCTUnwrap(itemStore.fetchItem(id: XCTUnwrap(UUID(uuidString: local.id)))).isUnavailable)
    }

    // MARK: - ListViewModel

    func test_toggleItemUnavailable_updatesItemOptimistically() {
        let item = makeItem("Butter")
        viewModel.items = [item]
        viewModel.toggleItemUnavailable(item)
        XCTAssertTrue(viewModel.items[0].isUnavailable)
        viewModel.toggleItemUnavailable(viewModel.items[0])
        XCTAssertFalse(viewModel.items[0].isUnavailable)
    }

    func test_itemFilter_controlsVisibleSections() {
        viewModel.items = [makeItem("Butter", category: .milch), makeItem("Eier", isChecked: true)]

        viewModel.itemFilter = .all
        XCTAssertEqual(viewModel.visibleOpenGroups.count, 1)
        XCTAssertEqual(viewModel.visibleCheckedItems.count, 1)

        viewModel.itemFilter = .open
        XCTAssertEqual(viewModel.visibleOpenGroups.count, 1)
        XCTAssertTrue(viewModel.visibleCheckedItems.isEmpty)

        viewModel.itemFilter = .done
        XCTAssertTrue(viewModel.visibleOpenGroups.isEmpty)
        XCTAssertEqual(viewModel.visibleCheckedItems.count, 1)
    }

    func test_checkAllItemsInCategory_checksOnlyThatCategory() {
        viewModel.items = [makeItem("Butter", category: .milch),
                           makeItem("Joghurt", category: .milch),
                           makeItem("Äpfel", category: .obstGemuese)]
        viewModel.checkAllItems(in: ItemCategory.milch.rawValue)

        let checkedNames = Set(viewModel.items.filter(\.isChecked).map(\.name))
        XCTAssertEqual(checkedNames, ["Butter", "Joghurt"])
        XCTAssertFalse(viewModel.items.first { $0.name == "Äpfel" }?.isChecked ?? true)
    }

    func test_clearForSignOut_resetsFilter() {
        viewModel.itemFilter = .done
        viewModel.clearForSignOut()
        XCTAssertEqual(viewModel.itemFilter, .all)
    }
}
