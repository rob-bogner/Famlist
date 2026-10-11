/*
 ListViewModelUndoCheckTests.swift
 FamlistTests

 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Abhaken mit Rückgängig“ (ListViewModel+UndoCheck).

 🔰 Notes for Beginners:
 - Der Haken wird sofort gespeichert. Der Hinweis merkt sich nur, welcher Artikel zuletzt abgehakt wurde.
 - Aufbau wie ListViewModelUndoDeleteTests: SwiftData im Speicher, echte SyncEngine ohne Netz.

 📝 Last Change:
 - Initial creation (Wunsch Robert 12.10.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ListViewModelUndoCheckTests: XCTestCase {

    private var sut: ListViewModel!
    private var store: SwiftDataItemStore!
    private var engine: SyncEngine!
    private let listId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

    override func setUp() async throws {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self, SyncOperation.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        store = SwiftDataItemStore(context: context)
        let repository = PreviewItemsRepository()
        sut = ListViewModel(listId: listId, repository: repository, itemStore: store,
                            listStore: SwiftDataListStore(context: context), startImmediately: false)
        engine = SyncEngine(repository: repository, itemStore: store, operationQueue: SyncOperationQueue(context: context),
                            hlcGenerator: HybridLogicalClockGenerator(nodeId: "test"), isOnline: { false })
        sut.configure(syncEngine: engine)
        let clock = HybridLogicalClockGenerator(nodeId: "test")
        for (name, checked) in [("Milch", false), ("Brot", false), ("Käse", true)] {
            try store.writeLocal(ItemModel(id: UUID().uuidString, name: name, isChecked: checked,
                                           listId: listId.uuidString),
                                 hlc: clock.tick(), tombstone: false, modifiedBy: "test")
        }
        try store.save()
        sut.refreshItemsFromStore()
    }

    override func tearDown() async throws {
        sut.pendingCheckTask?.cancel()
        sut.pendingDeletionTask?.cancel()
        sut = nil
        engine = nil
        store = nil
    }

    private func item(_ name: String) throws -> ItemModel {
        try XCTUnwrap(sut.items.first { $0.name == name })
    }

    /// Wartet, bis `condition` erfüllt ist (höchstens 2 s).
    private func waitUntil(_ condition: @escaping () throws -> Bool) async rethrows {
        for _ in 0..<200 where try !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    private func storedChecked(_ name: String) throws -> Bool? {
        try store.fetchItems(listId: listId).first { $0.name == name }?.isChecked
    }

    func test_checkFromList_offersUndo_withItemName() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        XCTAssertTrue(try item("Milch").isChecked)
        XCTAssertEqual(sut.pendingCheck?.itemId, try item("Milch").id)
        XCTAssertEqual(sut.pendingCheck?.message, "„Milch“ abgehakt")
        XCTAssertEqual(sut.pendingCheck?.listId, listId)
    }

    func test_undo_removesCheck_clearsHint_andIsStored() async throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        try await waitUntil { try self.storedChecked("Milch") == true }
        XCTAssertEqual(try storedChecked("Milch"), true, "der Haken ist sofort gespeichert")

        sut.undoPendingCheck()
        XCTAssertFalse(try item("Milch").isChecked)
        XCTAssertNil(sut.pendingCheck)
        try await waitUntil { try self.storedChecked("Milch") == false }
        XCTAssertEqual(try storedChecked("Milch"), false)
    }

    func test_checkWithoutUndoOffer_showsNoHint() throws {
        sut.toggleItemChecked(try item("Milch"))
        XCTAssertTrue(try item("Milch").isChecked)
        XCTAssertNil(sut.pendingCheck, "z. B. „Nicht gekauft“ aus dem Kassenzettel")
    }

    func test_uncheckFromList_showsNoHint() throws {
        sut.toggleItemChecked(try item("Käse"), offersUndo: true)
        XCTAssertFalse(try item("Käse").isChecked)
        XCTAssertNil(sut.pendingCheck, "nur Abhaken bietet Rückgängig an")
    }

    func test_secondCheck_replacesHint_undoOnlyAffectsLastItem() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        let first = sut.pendingCheck?.id
        sut.toggleItemChecked(try item("Brot"), offersUndo: true)
        XCTAssertNotEqual(sut.pendingCheck?.id, first)
        XCTAssertEqual(sut.pendingCheck?.message, "„Brot“ abgehakt")

        sut.undoPendingCheck()
        XCTAssertFalse(try item("Brot").isChecked)
        XCTAssertTrue(try item("Milch").isChecked, "der frühere Haken bleibt")
    }

    func test_manualUncheckOfSameItem_clearsHint() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        XCTAssertFalse(try item("Milch").isChecked)
        XCTAssertNil(sut.pendingCheck)
    }

    func test_uncheckOfOtherItem_keepsHint() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        sut.toggleItemChecked(try item("Käse"), offersUndo: true)
        XCTAssertEqual(sut.pendingCheck?.message, "„Milch“ abgehakt")
    }

    func test_deletion_replacesCheckHint() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        sut.stageDeletion(of: try item("Brot"))
        XCTAssertNil(sut.pendingCheck)
        XCTAssertEqual(sut.pendingDeletion?.count, 1)
    }

    func test_dismiss_keepsCheck() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        sut.dismissPendingCheck()
        XCTAssertNil(sut.pendingCheck)
        XCTAssertTrue(try item("Milch").isChecked, "Ausblenden ändert nichts am Haken")
        sut.undoPendingCheck()
        XCTAssertTrue(try item("Milch").isChecked, "ohne Hinweis gibt es nichts rückgängig zu machen")
    }

    func test_undo_afterItemWasUncheckedElsewhere_doesNothing() throws {
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)
        // Ein anderes Gerät hat den Haken inzwischen entfernt (Anzeige zeigt „offen“).
        let index = try XCTUnwrap(sut.items.firstIndex { $0.name == "Milch" })
        sut.items[index].isChecked = false
        sut.undoPendingCheck()
        XCTAssertFalse(try item("Milch").isChecked, "kein erneutes Abhaken")
        XCTAssertNil(sut.pendingCheck)
    }
}
