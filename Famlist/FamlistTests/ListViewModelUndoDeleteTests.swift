/*
 ListViewModelUndoDeleteTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Löschen mit Rückgängig“ aus dem Dock (ListViewModel+UndoDelete).

 🔰 Notes for Beginners:
 - stageDeletion blendet nur aus; erst commitPendingDeletion löscht in SwiftData.
 - Test-Artikel sind `.pendingCreate` → deleteItem purgt sie lokal ohne Netzwerk.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ListViewModelUndoDeleteTests: XCTestCase {

    private var sut: ListViewModel!
    private var store: SwiftDataItemStore!
    private let listId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    override func setUp() async throws {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        store = SwiftDataItemStore(context: context)
        sut = ListViewModel(listId: listId, repository: PreviewItemsRepository(), itemStore: store,
                            listStore: SwiftDataListStore(context: context), startImmediately: false)
        for (name, checked) in [("Milch", false), ("Brot", true), ("Käse", true)] {
            sut.storePendingChange(for: ItemModel(id: UUID().uuidString, name: name, isChecked: checked,
                                                  listId: listId.uuidString), status: .pendingCreate)
        }
    }

    override func tearDown() async throws {
        sut.pendingDeletionTask?.cancel()
        sut = nil
        store = nil
    }

    private func storedCount() throws -> Int { try store.fetchItems(listId: listId).count }

    func test_stageChecked_hidesCheckedItems_butKeepsThemStored() throws {
        sut.stageDeletion(.checked)
        XCTAssertEqual(sut.items.map(\.name), ["Milch"])
        XCTAssertEqual(sut.pendingDeletion?.count, 2)
        XCTAssertEqual(try storedCount(), 3, "Vor Ablauf des Toasts darf nichts gelöscht sein")
    }

    func test_undo_restoresItems_andClearsPending() throws {
        sut.stageDeletion(.all)
        XCTAssertTrue(sut.items.isEmpty)
        sut.undoPendingDeletion()
        XCTAssertNil(sut.pendingDeletion)
        XCTAssertEqual(Set(sut.items.map(\.name)), ["Milch", "Brot", "Käse"])
        XCTAssertEqual(try storedCount(), 3)
    }

    func test_commit_deletesFromStore() throws {
        sut.stageDeletion(.checked)
        sut.commitPendingDeletion()
        XCTAssertNil(sut.pendingDeletion)
        XCTAssertEqual(try storedCount(), 1)
        XCTAssertEqual(sut.items.map(\.name), ["Milch"])
    }

    func test_newStage_commitsPreviousOne() throws {
        sut.stageDeletion(.checked)
        sut.stageDeletion(.all)
        XCTAssertEqual(try storedCount(), 1, "Die erste Löschung wurde festgeschrieben")
        XCTAssertEqual(sut.pendingDeletion?.count, 1)
    }

    func test_stageChecked_withoutCheckedItems_doesNothing() {
        sut.stageDeletion(.checked)
        sut.commitPendingDeletion()
        sut.stageDeletion(.checked)
        XCTAssertNil(sut.pendingDeletion)
    }

    func test_expires_afterUndoDuration() async throws {
        sut.stageDeletion(.checked)
        try await Task.sleep(nanoseconds: UInt64((PendingItemDeletion.undoDuration + 0.5) * 1_000_000_000))
        XCTAssertNil(sut.pendingDeletion)
        XCTAssertEqual(try storedCount(), 1)
    }
}
