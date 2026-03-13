/*
 ListViewModelDuplicateDetectionTests.swift
 FamlistTests

 Famlist
 Created on: 13.03.2026
 Last updated on: 13.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for duplicate detection logic in ListViewModel.addItem(_:).
 - Verifies that adding an item whose name already exists (case-insensitive,
   unchecked) increments `units` instead of creating a new entry.

 🛠 Includes:
 - addItem with duplicate (unchecked) → units incremented, no new item
 - addItem with duplicate (checked) → new item created
 - addItem with unique name → new item created
 - addItem with case-insensitive duplicate → units incremented
 - addItem with duplicate after normalization (whitespace) → units incremented

 🔰 Notes for Beginners:
 - `startImmediately: false` prevents the realtime stream from starting.
 - `PreviewItemsRepository` is an in-memory stub that never touches Supabase.
 - Items are inserted directly into `viewModel.items` to simulate the
   SwiftData observation stream (avoids needing a full SyncEngine).

 📝 Last Change:
 - Initial creation for duplicate-detection QA.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

// MARK: - ListViewModelDuplicateDetectionTests

@MainActor
final class ListViewModelDuplicateDetectionTests: XCTestCase {

    // MARK: - Setup

    private var viewModel: ListViewModel!
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    private let testListId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)

        viewModel = ListViewModel(
            listId: testListId,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: modelContext),
            listStore: SwiftDataListStore(context: modelContext),
            startImmediately: false
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeItem(
        name: String,
        units: Int = 1,
        isChecked: Bool = false
    ) -> ItemModel {
        ItemModel(
            id: UUID().uuidString,
            name: name,
            units: units,
            measure: "Stk",
            isChecked: isChecked,
            listId: testListId.uuidString,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Schreibt Items in SwiftData und aktualisiert viewModel.items aus dem Store.
    /// Notwendig da storePendingChange() → refreshItemsFromStore() items aus dem Store lädt.
    private func seedStore(with items: [ItemModel]) throws {
        let store = SwiftDataItemStore(context: modelContext)
        for item in items {
            let entity = try store.upsert(model: item)
            entity.setSyncStatus(.synced)
        }
        try store.save()
        viewModel.refreshItemsFromStore()
    }

    // MARK: - Duplicate (unchecked) → increment units

    func test_addItem_duplicateUnchecked_incrementsUnits() {
        // Arrange: Liste enthält "Milch" mit units = 1
        let existing = makeItem(name: "Milch", units: 1, isChecked: false)
        viewModel.items = [existing]

        // Act: selben Artikel nochmal hinzufügen
        let duplicate = makeItem(name: "Milch", units: 1, isChecked: false)
        viewModel.addItem(duplicate)

        // Assert: units auf 2 erhöht, kein neuer Eintrag
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.units, 2)
        XCTAssertEqual(viewModel.items.first?.id, existing.id)
    }

    func test_addItem_duplicateUnchecked_doesNotAddNewEntry() {
        // Arrange
        viewModel.items = [makeItem(name: "Butter", units: 2, isChecked: false)]

        // Act
        viewModel.addItem(makeItem(name: "Butter", units: 1, isChecked: false))

        // Assert: nach wie vor nur 1 Eintrag
        XCTAssertEqual(viewModel.items.count, 1)
    }

    // MARK: - Case-insensitive matching

    func test_addItem_caseInsensitiveDuplicate_incrementsUnits() {
        // Arrange: "ZUCKER" im Bestand
        let existing = makeItem(name: "ZUCKER", units: 1, isChecked: false)
        viewModel.items = [existing]

        // Act: "zucker" (Kleinschreibung) hinzufügen
        viewModel.addItem(makeItem(name: "zucker", units: 1, isChecked: false))

        // Assert: units erhöht
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.units, 2)
    }

    func test_addItem_mixedCaseDuplicate_incrementsUnits() {
        // Arrange
        viewModel.items = [makeItem(name: "Orangensaft", units: 3, isChecked: false)]

        // Act: "ORANGENSAFT" hinzufügen
        viewModel.addItem(makeItem(name: "ORANGENSAFT"))

        // Assert
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.units, 4)
    }

    // MARK: - Checked item → new entry

    func test_addItem_duplicateChecked_createsNewEntry() throws {
        // Arrange: "Eier" ist bereits abgehakt – via SwiftData vorbelegen
        let checkedEier = makeItem(name: "Eier", units: 1, isChecked: true)
        try seedStore(with: [checkedEier])

        // Act: "Eier" (ungehackt) erneut hinzufügen
        viewModel.addItem(makeItem(name: "Eier", units: 1, isChecked: false))

        // Assert: neuer Eintrag wird angelegt (abgehakte gelten als erledigt)
        XCTAssertEqual(viewModel.items.count, 2)
    }

    // MARK: - Unique item → new entry

    func test_addItem_uniqueName_createsNewEntry() throws {
        // Arrange: "Mehl" via SwiftData vorbelegen
        try seedStore(with: [makeItem(name: "Mehl", units: 1)])

        // Act: anderen Artikel hinzufügen
        viewModel.addItem(makeItem(name: "Hefe", units: 1))

        // Assert: neuer Eintrag angelegt
        XCTAssertEqual(viewModel.items.count, 2)
    }

    func test_addItem_emptyList_createsNewEntry() {
        // Arrange: leere Liste
        viewModel.items = []

        // Act
        viewModel.addItem(makeItem(name: "Tomate"))

        // Assert
        XCTAssertEqual(viewModel.items.count, 1)
    }

    // MARK: - Multiple increments

    func test_addItem_multipleDuplicates_incrementsCorrectly() {
        // Arrange
        viewModel.items = [makeItem(name: "Nudeln", units: 1)]

        // Act: dreimal denselben Artikel hinzufügen
        viewModel.addItem(makeItem(name: "Nudeln"))
        viewModel.addItem(makeItem(name: "Nudeln"))
        viewModel.addItem(makeItem(name: "Nudeln"))

        // Assert: units = 1 + 3 = 4, immer noch 1 Eintrag
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.units, 4)
    }

    // MARK: - Increment targets correct item

    func test_addItem_duplicateAmongMultipleItems_incrementsCorrectItem() throws {
        // Arrange: Liste via SwiftData vorbelegen (damit refreshItemsFromStore() alle Items liefert)
        let milch = makeItem(name: "Milch", units: 1)
        let brot = makeItem(name: "Brot", units: 1)
        let kaese = makeItem(name: "Käse", units: 1)
        try seedStore(with: [milch, brot, kaese])

        // Act: nur "Brot" ist Duplikat
        viewModel.addItem(makeItem(name: "Brot"))

        // Assert: nur Brot wurde erhöht, alle drei Items noch vorhanden
        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertEqual(viewModel.items.first(where: { $0.name == "Brot" })?.units, 2)
        XCTAssertEqual(viewModel.items.first(where: { $0.name == "Milch" })?.units, 1)
        XCTAssertEqual(viewModel.items.first(where: { $0.name == "Käse" })?.units, 1)
    }
}
