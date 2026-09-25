/*
 ShoppingCompletionTests.swift
 FamlistTests

 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Einkauf erledigt“ (ListViewModel+ShoppingCompletion).

 🔰 Notes for Beginners:
 - Nur der Wechsel „noch offen → alles abgehakt“ durch eine Nutzeraktion setzt `shoppingCompletedEvent`.
 - In-Memory-SwiftData, keine Netzwerkaufrufe (PreviewItemsRepository, startImmediately: false).

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ShoppingCompletionTests: XCTestCase {

    private var sut: ListViewModel!
    private let listId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

    override func setUp() async throws {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        sut = ListViewModel(listId: listId, repository: PreviewItemsRepository(),
                            itemStore: SwiftDataItemStore(context: context),
                            listStore: SwiftDataListStore(context: context), startImmediately: false)
    }

    override func tearDown() async throws {
        sut = nil
    }

    private func item(_ name: String, checked: Bool) -> ItemModel {
        ItemModel(id: UUID().uuidString, name: name, isChecked: checked, listId: listId.uuidString)
    }

    func test_isShoppingComplete_falseForEmptyList() {
        sut.items = []
        XCTAssertFalse(sut.isShoppingComplete)
    }

    func test_lastItemChecked_setsEvent() {
        sut.items = [item("Milch", checked: true), item("Brot", checked: true)]
        sut.noteCheckChange(wasComplete: false)
        XCTAssertNotNil(sut.shoppingCompletedEvent)
    }

    func test_stillOpenItems_noEvent() {
        sut.items = [item("Milch", checked: true), item("Brot", checked: false)]
        sut.noteCheckChange(wasComplete: false)
        XCTAssertNil(sut.shoppingCompletedEvent)
    }

    func test_alreadyComplete_noNewEvent() {
        sut.items = [item("Milch", checked: true)]
        sut.noteCheckChange(wasComplete: true)
        XCTAssertNil(sut.shoppingCompletedEvent, "Liste war schon erledigt (z. B. Listenwechsel)")
    }

    func test_toggleItemChecked_lastOpenItem_setsEvent() {
        let open = item("Brot", checked: false)
        sut.items = [item("Milch", checked: true), open]
        sut.toggleItemChecked(open)
        XCTAssertTrue(sut.isShoppingComplete)
        XCTAssertNotNil(sut.shoppingCompletedEvent)
    }

    func test_toggleItemChecked_unchecking_noEvent() {
        let done = item("Brot", checked: true)
        sut.items = [item("Milch", checked: true), done]
        sut.toggleItemChecked(done)
        XCTAssertNil(sut.shoppingCompletedEvent)
    }
}
