/*
 ListViewModelBulkDeleteTests.swift
 FamlistTests

 Famlist
 Created on: 14.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests für die drei Bulk-Delete-Methoden in ListViewModel+BulkActions.

 🛠 Includes:
 - deleteAllItems(): löscht alle, leere Liste, gemischte Liste
 - deleteCheckedItems(): nur abgehakte, keine abgehakten, alle abgehakt
 - deleteUncheckedItems(): nur offene, keine offenen, alle offen
 - Seiteneffekte: andere Artikel bleiben erhalten

 🔰 Notes for Beginners:
 - SwiftData Container ist in-memory für Testisolation.
 - deleteItem() ist fire-and-forget (SyncEngine); wir prüfen nur die lokale items-Liste.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ListViewModelBulkDeleteTests: XCTestCase {

    var sut: ListViewModel!
    private let testListId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        sut = ListViewModel(
            listId: testListId,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: false
        )
    }

    override func tearDown() async throws {
        sut = nil
    }

    // MARK: - Helpers

    /// Erstellt ein ItemModel und persistiert es direkt in SwiftData,
    /// damit refreshItemsFromStore() nach deleteItem() korrekte Ergebnisse liefert.
    @discardableResult
    private func addItem(name: String, isChecked: Bool) -> ItemModel {
        let item = ItemModel(
            id: UUID().uuidString,
            name: name,
            units: 1,
            measure: "Stück",
            isChecked: isChecked,
            listId: testListId.uuidString,
            ownerPublicId: "owner"
        )
        sut.storePendingChange(for: item, status: .pendingCreate)
        return item
    }

    private func populate(checked: Int, unchecked: Int) {
        for i in 1...max(checked, 1) where i <= checked {
            addItem(name: "Checked\(i)", isChecked: true)
        }
        for i in 1...max(unchecked, 1) where i <= unchecked {
            addItem(name: "Unchecked\(i)", isChecked: false)
        }
    }

    // MARK: - deleteAllItems()

    func test_deleteAll_removesEveryItem() {
        populate(checked: 2, unchecked: 3)
        sut.deleteAllItems()
        XCTAssertTrue(sut.items.isEmpty)
    }

    func test_deleteAll_onEmptyList_doesNotCrash() {
        sut.items = []
        sut.deleteAllItems() // must not crash
        XCTAssertTrue(sut.items.isEmpty)
    }

    func test_deleteAll_withOnlyChecked_removesAll() {
        populate(checked: 3, unchecked: 0)
        sut.deleteAllItems()
        XCTAssertTrue(sut.items.isEmpty)
    }

    func test_deleteAll_withOnlyUnchecked_removesAll() {
        populate(checked: 0, unchecked: 3)
        sut.deleteAllItems()
        XCTAssertTrue(sut.items.isEmpty)
    }

    // MARK: - deleteCheckedItems()

    func test_deleteChecked_removesOnlyCheckedItems() {
        populate(checked: 2, unchecked: 3)
        sut.deleteCheckedItems()
        XCTAssertTrue(sut.items.allSatisfy { !$0.isChecked })
        XCTAssertEqual(sut.items.count, 3)
    }

    func test_deleteChecked_preservesUncheckedItems() {
        addItem(name: "Milch", isChecked: false)
        addItem(name: "Brot",  isChecked: true)

        sut.deleteCheckedItems()

        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.name, "Milch")
    }

    func test_deleteChecked_whenNoneChecked_doesNothing() {
        populate(checked: 0, unchecked: 3)
        sut.deleteCheckedItems()
        XCTAssertEqual(sut.items.count, 3)
    }

    func test_deleteChecked_whenAllChecked_emptiesList() {
        populate(checked: 4, unchecked: 0)
        sut.deleteCheckedItems()
        XCTAssertTrue(sut.items.isEmpty)
    }

    // MARK: - deleteUncheckedItems()

    func test_deleteUnchecked_removesOnlyUncheckedItems() {
        populate(checked: 2, unchecked: 3)
        sut.deleteUncheckedItems()
        XCTAssertTrue(sut.items.allSatisfy { $0.isChecked })
        XCTAssertEqual(sut.items.count, 2)
    }

    func test_deleteUnchecked_preservesCheckedItems() {
        addItem(name: "Butter", isChecked: false)
        addItem(name: "Käse",   isChecked: true)

        sut.deleteUncheckedItems()

        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.name, "Käse")
    }

    func test_deleteUnchecked_whenNoneUnchecked_doesNothing() {
        populate(checked: 3, unchecked: 0)
        sut.deleteUncheckedItems()
        XCTAssertEqual(sut.items.count, 3)
    }

    func test_deleteUnchecked_whenAllUnchecked_emptiesList() {
        populate(checked: 0, unchecked: 4)
        sut.deleteUncheckedItems()
        XCTAssertTrue(sut.items.isEmpty)
    }

    // MARK: - Kombiniert

    func test_deleteChecked_thenDeleteUnchecked_emptiesList() {
        populate(checked: 2, unchecked: 2)
        sut.deleteCheckedItems()
        sut.deleteUncheckedItems()
        XCTAssertTrue(sut.items.isEmpty)
    }
}
