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
 - „Alle abhaken“ im Dock und im Abschnittskopf (12.10.2026).
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
        // Kategorien: Milch und Käse „Milchprodukte“, Brot „Backwaren“ (für „Alle abhaken“ im Abschnittskopf).
        for (name, checked, category) in [("Milch", false, "Milchprodukte"), ("Brot", false, "Backwaren"),
                                          ("Käse", true, "Milchprodukte")] {
            try store.writeLocal(ItemModel(id: UUID().uuidString, name: name, isChecked: checked,
                                           category: category, listId: listId.uuidString),
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
        XCTAssertEqual(sut.pendingCheck?.itemIds, [try item("Milch").id])
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

    // MARK: - „Alle abhaken“ (Dock und Abschnittskopf)

    func test_checkAllInCategory_offersUndo_andUndoKeepsEarlierChecks() async throws {
        try store.writeLocal(ItemModel(id: UUID().uuidString, name: "Joghurt", category: "Milchprodukte",
                                       listId: listId.uuidString),
                             hlc: HybridLogicalClockGenerator(nodeId: "test2").tick(), tombstone: false, modifiedBy: "test")
        try store.save()
        sut.refreshItemsFromStore()

        sut.checkAllItems(in: "Milchprodukte")
        XCTAssertEqual(sut.pendingCheck?.message, "2 Artikel abgehakt", "Käse war schon abgehakt und zählt nicht mit")
        XCTAssertTrue(try item("Milch").isChecked)
        XCTAssertTrue(try item("Joghurt").isChecked)
        try await waitUntil { try self.storedChecked("Joghurt") == true }

        sut.undoPendingCheck()
        XCTAssertNil(sut.pendingCheck)
        XCTAssertFalse(try item("Milch").isChecked)
        XCTAssertFalse(try item("Joghurt").isChecked)
        XCTAssertTrue(try item("Käse").isChecked, "der frühere Haken bleibt")
        XCTAssertFalse(try item("Brot").isChecked)
        try await waitUntil { try self.storedChecked("Milch") == false && self.storedChecked("Joghurt") == false }
        XCTAssertEqual(try storedChecked("Milch"), false)
        XCTAssertEqual(try storedChecked("Joghurt"), false)
        XCTAssertEqual(try storedChecked("Käse"), true)
    }

    func test_checkAllInCategory_withOneOpenItem_namesTheItem() throws {
        sut.checkAllItems(in: "Backwaren")
        XCTAssertEqual(sut.pendingCheck?.message, "„Brot“ abgehakt")
    }

    func test_dockCheckAll_offersUndo_andUndoRestoresPreviousState() async throws {
        sut.toggleAllItems()
        await waitUntil { self.sut.pendingCheck != nil }
        XCTAssertEqual(sut.pendingCheck?.message, "2 Artikel abgehakt", "Milch und Brot; Käse war schon abgehakt")
        XCTAssertTrue(sut.items.allSatisfy(\.isChecked))
        try await waitUntil { try self.storedChecked("Brot") == true }

        sut.undoPendingCheck()
        XCTAssertFalse(try item("Milch").isChecked)
        XCTAssertFalse(try item("Brot").isChecked)
        XCTAssertTrue(try item("Käse").isChecked, "nicht „Zurücksetzen“: der frühere Haken bleibt")
        try await waitUntil { try self.storedChecked("Milch") == false && self.storedChecked("Brot") == false }
        XCTAssertEqual(try storedChecked("Brot"), false)
        XCTAssertEqual(try storedChecked("Käse"), true)
    }

    func test_dockReset_showsNoHint() async throws {
        sut.toggleAllItems()
        await waitUntil { self.sut.pendingCheck != nil }
        sut.toggleAllItems()                                    // alles abgehakt → „Zurücksetzen“
        await waitUntil { self.sut.items.allSatisfy { !$0.isChecked } }
        XCTAssertTrue(sut.items.allSatisfy { !$0.isChecked })
        XCTAssertNil(sut.pendingCheck, "„Zurücksetzen“ bietet kein Rückgängig an")
    }

    func test_bulkUndo_skipsItemsUncheckedInBetween() async throws {
        sut.toggleAllItems()
        await waitUntil { self.sut.pendingCheck != nil }
        sut.toggleItemChecked(try item("Milch"), offersUndo: true)      // von Hand wieder offen
        XCTAssertNotNil(sut.pendingCheck, "der Hinweis für die übrigen Artikel bleibt")
        sut.undoPendingCheck()
        XCTAssertFalse(try item("Milch").isChecked)
        XCTAssertFalse(try item("Brot").isChecked)
        XCTAssertTrue(try item("Käse").isChecked)
    }
}
