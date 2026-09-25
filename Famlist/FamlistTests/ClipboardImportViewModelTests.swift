/*
 ClipboardImportViewModelTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Import aus Zwischenablage (Hybrid-Sheet): leere Ablage, nichts erkannt, Auswahl, Übernahme in die Liste
   (neu anlegen und gleichnamigen Artikel erhöhen), offline über die echte SyncEngine.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ClipboardImportViewModelTests: XCTestCase {
    private var list: ListViewModel!
    private var store: SwiftDataItemStore!
    private var engine: SyncEngine!
    private let listId = UUID()

    override func setUp() async throws {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self, SyncOperation.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        store = SwiftDataItemStore(context: context)
        let repository = PreviewItemsRepository()
        list = ListViewModel(listId: listId, repository: repository, itemStore: store,
                             listStore: SwiftDataListStore(context: context), startImmediately: false)
        engine = SyncEngine(repository: repository, itemStore: store, operationQueue: SyncOperationQueue(context: context),
                            hlcGenerator: HybridLogicalClockGenerator(nodeId: "test"), isOnline: { false })
        list.configure(syncEngine: engine)
    }

    override func tearDown() async throws {
        list = nil
        engine = nil
        store = nil
    }

    private func waitForItems(_ count: Int) async throws -> [ItemEntity] {
        for _ in 0..<200 {
            let items = try store.fetchItems(listId: listId)
            if items.count >= count && !list.isBulkMutationActive { return items }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return try store.fetchItems(listId: listId)
    }

    func test_emptyClipboard_showsError() {
        let sut = ClipboardImportViewModel(readClipboard: { "  \n" })
        sut.load()
        XCTAssertNil(sut.result)
        XCTAssertEqual(sut.errorMessage, String(localized: "import.error.emptyClipboard"))
    }

    func test_noItems_showsError() {
        let sut = ClipboardImportViewModel(readClipboard: { "---\n***" })
        sut.load()
        XCTAssertNil(sut.result)
        XCTAssertEqual(sut.errorMessage, String(localized: "import.error.noItemsFound"))
    }

    func test_load_selectsAll_andToggleAllSwitches() {
        let sut = ClipboardImportViewModel(readClipboard: { "Milch\nBrot\nEier" })
        sut.load()
        XCTAssertEqual(sut.items.count, 3)
        XCTAssertTrue(sut.allSelected)
        sut.toggleAll()
        XCTAssertTrue(sut.selected.isEmpty)
        sut.toggle(1)
        XCTAssertEqual(sut.selected, [1])
        XCTAssertEqual(sut.importSelected(into: list), 1)
    }

    func test_import_createsNew_andIncrementsExisting() async throws {
        try store.writeLocal(ItemModel(id: UUID().uuidString, name: "Milch", units: 1, listId: listId.uuidString),
                             hlc: HybridLogicalClockGenerator(nodeId: "x").tick(), tombstone: false, modifiedBy: "x")
        try store.save()
        let sut = ClipboardImportViewModel(readClipboard: { "Milch\nBrot" })
        sut.load()
        XCTAssertEqual(sut.importSelected(into: list), 2)

        let items = try await waitForItems(2)
        XCTAssertEqual(Set(items.map(\.name)), ["Milch", "Brot"], "kein Duplikat für Milch")
        XCTAssertEqual(items.first { $0.name == "Milch" }?.units, 2)
        XCTAssertGreaterThan(engine.pendingOperations, 0, "offline: wartet in der Warteschlange")
    }

    func test_nothingSelected_importsNothing() {
        let sut = ClipboardImportViewModel(readClipboard: { "Milch" })
        sut.load()
        sut.toggle(0)
        XCTAssertEqual(sut.importSelected(into: list), 0)
    }
}
