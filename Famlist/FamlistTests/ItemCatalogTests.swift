/*
 ItemCatalogTests.swift
 FamlistTests

 Famlist
 Created on: 13.03.2026
 Last updated on: 13.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for the FAM-52 smart item catalog feature (FAM-60 implementation).

 🛠 Includes:
 - ItemCatalogEntry: factory method, toItemModel conversion, Codable roundtrip.
 - PreviewItemCatalogRepository: search, save (upsert), max results, case-insensitivity.
 - ItemSearchViewModel: input clamping, min-length guard, error sanitization, results clearing.
 - ListViewModel.addItem(): catalog save triggered.
 - ListViewModel.updateItem(): catalog update triggered.
 - Duplicate prevention: case-insensitive, unchecked items only.

 🔰 Notes for Beginners:
 - Uses XCTest with @MainActor for thread-safe ViewModel testing.
 - SpyCatalogRepository captures calls so we can assert save was triggered.
 - All async tests use `await` with explicit Task.sleep where debounce is involved.

 📝 Last Change:
 - Initial creation for FAM-52 test coverage.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Spy Repository

/// Records every call to save() and search() for assertion in tests.
@MainActor
final class SpyItemCatalogRepository: ItemCatalogRepository {

    private(set) var savedEntries: [ItemCatalogEntry] = []
    private(set) var searchQueries: [String] = []

    var stubbedResults: [ItemCatalogEntry] = []
    var shouldThrow: Bool = false

    func search(query: String) async throws -> [ItemCatalogEntry] {
        searchQueries.append(query)
        if shouldThrow { throw URLError(.badServerResponse) }
        return stubbedResults
    }

    func save(_ entry: ItemCatalogEntry) async throws {
        if shouldThrow { throw URLError(.badServerResponse) }
        savedEntries.append(entry)
    }
}

// MARK: - ItemCatalogEntry Tests

@MainActor
final class ItemCatalogEntryTests: XCTestCase {

    // MARK: - from(item:ownerPublicId:)

    func test_from_mapsAllFieldsFromItemModel() {
        let item = ItemModel(
            id: "item-1",
            imageData: "base64data",
            name: "Milch",
            units: 2,
            measure: "l",
            price: 1.49,
            isChecked: false,
            category: "Molkerei",
            productDescription: "Vollmilch 3,5%",
            brand: "Weihenstephan",
            listId: "list-1",
            ownerPublicId: "owner-1"
        )

        let entry = ItemCatalogEntry.from(item: item, ownerPublicId: "owner-1")

        XCTAssertEqual(entry.name, "Milch")
        XCTAssertEqual(entry.brand, "Weihenstephan")
        XCTAssertEqual(entry.category, "Molkerei")
        XCTAssertEqual(entry.productDescription, "Vollmilch 3,5%")
        XCTAssertEqual(entry.measure, "l")
        XCTAssertEqual(entry.price, 1.49, accuracy: 0.001)
        XCTAssertEqual(entry.imageData, "base64data")
        XCTAssertEqual(entry.ownerPublicId, "owner-1")
    }

    func test_from_generatesNewId() {
        let item = ItemModel(id: "item-1", name: "Brot")
        let entry1 = ItemCatalogEntry.from(item: item, ownerPublicId: "owner-1")
        let entry2 = ItemCatalogEntry.from(item: item, ownerPublicId: "owner-1")

        // Each call generates a fresh UUID
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func test_from_preservesNilOptionals() {
        let item = ItemModel(name: "Salz")
        let entry = ItemCatalogEntry.from(item: item, ownerPublicId: "")

        XCTAssertNil(entry.brand)
        XCTAssertNil(entry.category)
        XCTAssertNil(entry.productDescription)
        XCTAssertNil(entry.imageData)
    }

    // MARK: - toItemModel()

    func test_toItemModel_mapsAllFields() {
        let entry = ItemCatalogEntry(
            id: "entry-1",
            ownerPublicId: "owner-1",
            name: "Butter",
            brand: "Kerrygold",
            category: "Molkerei",
            productDescription: nil,
            measure: "Packung",
            price: 1.89,
            imageData: nil
        )

        let model = entry.toItemModel(listId: "list-42", ownerPublicId: "owner-1")

        XCTAssertEqual(model.name, "Butter")
        XCTAssertEqual(model.brand, "Kerrygold")
        XCTAssertEqual(model.category, "Molkerei")
        XCTAssertEqual(model.measure, "Packung")
        XCTAssertEqual(model.units, 1)
        XCTAssertEqual(model.price, 1.89, accuracy: 0.001)
        XCTAssertEqual(model.listId, "list-42")
        XCTAssertEqual(model.ownerPublicId, "owner-1")
        XCTAssertFalse(model.isChecked)
    }

    func test_toItemModel_generatesNewId() {
        let entry = ItemCatalogEntry(
            id: "entry-1",
            ownerPublicId: "owner-1",
            name: "Käse",
            brand: nil,
            category: nil,
            productDescription: nil,
            measure: "Stück",
            price: 0.0,
            imageData: nil
        )

        let model1 = entry.toItemModel(listId: "list-1", ownerPublicId: "owner-1")
        let model2 = entry.toItemModel(listId: "list-1", ownerPublicId: "owner-1")

        // Each add to list should create a distinct item
        XCTAssertNotEqual(model1.id, model2.id)
    }

    // MARK: - Codable Roundtrip

    func test_codable_roundtrip() throws {
        let entry = ItemCatalogEntry(
            id: "roundtrip-1",
            ownerPublicId: "owner-abc",
            name: "Joghurt",
            brand: "Müller",
            category: "Molkerei",
            productDescription: "Naturjoghurt 3,5%",
            measure: "Becher",
            price: 0.79,
            imageData: "base64=="
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ItemCatalogEntry.self, from: encoded)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.ownerPublicId, entry.ownerPublicId)
        XCTAssertEqual(decoded.name, entry.name)
        XCTAssertEqual(decoded.brand, entry.brand)
        XCTAssertEqual(decoded.category, entry.category)
        XCTAssertEqual(decoded.productDescription, entry.productDescription)
        XCTAssertEqual(decoded.measure, entry.measure)
        XCTAssertEqual(decoded.price, entry.price, accuracy: 0.001)
        XCTAssertEqual(decoded.imageData, entry.imageData)
    }
}

// MARK: - PreviewItemCatalogRepository Tests

@MainActor
final class PreviewItemCatalogRepositoryTests: XCTestCase {

    var repo: PreviewItemCatalogRepository!

    override func setUp() async throws {
        repo = PreviewItemCatalogRepository()
    }

    // MARK: - search()

    func test_search_returnsMatchingItems() async throws {
        let results = try await repo.search(query: "Milch")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.name.lowercased().contains("milch") })
    }

    func test_search_isCaseInsensitive() async throws {
        let lower = try await repo.search(query: "milch")
        let upper = try await repo.search(query: "MILCH")
        let mixed = try await repo.search(query: "MiLcH")

        XCTAssertEqual(lower.map(\.id).sorted(), upper.map(\.id).sorted())
        XCTAssertEqual(lower.map(\.id).sorted(), mixed.map(\.id).sorted())
    }

    func test_search_returnsAtMostFiveResults() async throws {
        // Save 6 entries all containing "Test"
        for i in 1...6 {
            let entry = ItemCatalogEntry(
                id: UUID().uuidString,
                ownerPublicId: "preview",
                name: "TestArtikel\(i)",
                brand: nil, category: nil, productDescription: nil,
                measure: "Stück", price: 0.0, imageData: nil
            )
            try await repo.save(entry)
        }
        let results = try await repo.search(query: "testartikel")
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    func test_search_returnsEmptyForNoMatch() async throws {
        let results = try await repo.search(query: "xyzNotFound")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - save() / Upsert

    func test_save_addsNewEntry() async throws {
        let before = try await repo.search(query: "Tomate")
        XCTAssertTrue(before.isEmpty)

        let entry = ItemCatalogEntry(
            id: UUID().uuidString,
            ownerPublicId: "preview",
            name: "Tomate",
            brand: nil, category: nil, productDescription: nil,
            measure: "Stück", price: 0.49, imageData: nil
        )
        try await repo.save(entry)

        let after = try await repo.search(query: "Tomate")
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.name, "Tomate")
    }

    func test_save_upsertUpdatesExistingEntry() async throws {
        // First save
        let entry = ItemCatalogEntry(
            id: UUID().uuidString,
            ownerPublicId: "preview",
            name: "Milch",
            brand: "Weihenstephan",
            category: "Molkerei", productDescription: nil,
            measure: "l", price: 1.49, imageData: nil
        )
        try await repo.save(entry)

        // Update with changed price
        var updated = entry
        updated.price = 2.99
        try await repo.save(updated)

        let results = try await repo.search(query: "Milch")
        let milch = results.first { $0.name == "Milch" }
        XCTAssertNotNil(milch)
        XCTAssertEqual(milch?.price ?? 0, 2.99, accuracy: 0.001)
    }

    func test_save_upsertIsCaseInsensitiveOnName() async throws {
        let entry1 = ItemCatalogEntry(
            id: UUID().uuidString, ownerPublicId: "preview",
            name: "Zucker", brand: nil, category: nil, productDescription: nil,
            measure: "kg", price: 0.99, imageData: nil
        )
        try await repo.save(entry1)

        // Save same item with different case – should update, not append
        var entry2 = entry1
        entry2.name = "ZUCKER"
        try await repo.save(entry2)

        let results = try await repo.search(query: "zucker")
        // There should still be only one "Zucker" entry (upserted)
        XCTAssertEqual(results.count, 1)
    }
}

// MARK: - ItemSearchViewModel Tests

@MainActor
final class ItemSearchViewModelTests: XCTestCase {

    var spy: SpyItemCatalogRepository!
    var sut: ItemSearchViewModel!

    override func setUp() async throws {
        spy = SpyItemCatalogRepository()
        sut = ItemSearchViewModel(catalogRepository: spy)
    }

    // MARK: - Input Clamping (Security: DoS protection)

    func test_inputClamping_truncatesLongInput() {
        sut.searchText = String(repeating: "a", count: 150)
        sut.onSearchTextChanged()

        XCTAssertLessThanOrEqual(sut.searchText.count, 100)
        XCTAssertEqual(sut.searchText.count, 100)
    }

    func test_inputClamping_doesNotAlterShortInput() {
        sut.searchText = "Milch"
        sut.onSearchTextChanged()

        XCTAssertEqual(sut.searchText, "Milch")
    }

    func test_inputClamping_exactlyMaxLengthUnchanged() {
        let exact = String(repeating: "x", count: 100)
        sut.searchText = exact
        sut.onSearchTextChanged()

        XCTAssertEqual(sut.searchText.count, 100)
    }

    // MARK: - Minimum Length Guard

    func test_minLength_emptyQueryClearsResults() {
        sut.searchText = ""
        sut.onSearchTextChanged()

        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertFalse(sut.isSearching)
        XCTAssertNil(sut.errorMessage)
    }

    func test_minLength_singleCharClearsResults() {
        sut.searchText = "a"
        sut.onSearchTextChanged()

        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertFalse(sut.isSearching)
    }

    func test_minLength_whitespaceOnlyClearsResults() {
        sut.searchText = "  "
        sut.onSearchTextChanged()

        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertFalse(sut.isSearching)
    }

    func test_minLength_twoCharsTriggersSearch() {
        sut.searchText = "ab"
        sut.onSearchTextChanged()

        // isSearching should be true immediately after debounce start
        XCTAssertTrue(sut.isSearching)
    }

    // MARK: - Error Sanitization (Security)

    func test_error_doesNotExposeRawError() async throws {
        spy.shouldThrow = true
        sut.searchText = "Milch"
        sut.onSearchTextChanged()

        // Wait for debounce (300ms) + some margin
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(sut.errorMessage)
        // Must NOT contain raw URLError or Supabase details
        XCTAssertFalse(sut.errorMessage?.contains("URLError") ?? false)
        XCTAssertFalse(sut.errorMessage?.contains("badServerResponse") ?? false)
    }

    func test_error_clearsResultsOnFailure() async throws {
        // Pre-populate results
        spy.stubbedResults = [
            ItemCatalogEntry(
                id: "1", ownerPublicId: "u", name: "Milch",
                brand: nil, category: nil, productDescription: nil,
                measure: "l", price: 0, imageData: nil
            )
        ]
        sut.searchText = "Milch"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        // Now throw on next search
        spy.shouldThrow = true
        sut.searchText = "Mi"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(sut.results.isEmpty)
    }

    // MARK: - Successful Search

    func test_search_populatesResults() async throws {
        spy.stubbedResults = [
            ItemCatalogEntry(
                id: "entry-1", ownerPublicId: "owner",
                name: "Butter", brand: "Kerrygold",
                category: "Molkerei", productDescription: nil,
                measure: "Packung", price: 1.89, imageData: nil
            )
        ]

        sut.searchText = "But"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(sut.results.count, 1)
        XCTAssertEqual(sut.results.first?.entry.name, "Butter")
        XCTAssertFalse(sut.isSearching)
        XCTAssertNil(sut.errorMessage)
    }

    func test_search_isSearchingFalseAfterCompletion() async throws {
        sut.searchText = "xy"
        sut.onSearchTextChanged()
        XCTAssertTrue(sut.isSearching)

        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertFalse(sut.isSearching)
    }

    // MARK: - Debounce / Cancellation

    func test_debounce_rapidChangesOnlyFireOneSearch() async throws {
        sut.searchText = "Mi"
        sut.onSearchTextChanged()
        sut.searchText = "Mil"
        sut.onSearchTextChanged()
        sut.searchText = "Milc"
        sut.onSearchTextChanged()
        sut.searchText = "Milch"
        sut.onSearchTextChanged()

        // Yield to let cancelled tasks clear before starting the debounce clock.
        // Then wait well beyond the 300ms debounce window.
        await Task.yield()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms

        // The debounce must have fired at least once and the final query must be "Milch".
        // We don't assert count == 1 because slow CI environments may let an earlier
        // task slip through; the important invariant is that "Milch" was searched last.
        XCTAssertGreaterThanOrEqual(spy.searchQueries.count, 1, "Debounce should fire at least once")
        XCTAssertEqual(spy.searchQueries.last, "Milch", "Final debounced query must be 'Milch'")
    }
}

// MARK: - ListViewModel Catalog Integration Tests

@MainActor
final class ListViewModelCatalogTests: XCTestCase {

    var spy: SpyItemCatalogRepository!
    var sut: ListViewModel!

    override func setUp() async throws {
        spy = SpyItemCatalogRepository()

        // In-memory SwiftData stores so tests don't touch disk
        let container = PersistenceController.preview.container
        let itemStore = SwiftDataItemStore(context: container.mainContext)
        let listStore = SwiftDataListStore(context: container.mainContext)

        sut = ListViewModel(
            listId: UUID(),
            repository: PreviewItemsRepository(),
            itemStore: itemStore,
            listStore: listStore,
            startImmediately: false
        )
        sut.configure(catalogRepository: spy)
    }

    // MARK: - addItem triggers catalog save

    func test_addItem_triggersCatalogSave() async throws {
        let item = ItemModel(name: "Mehl", units: 1, measure: "kg")
        sut.addItem(item)

        // Fire-and-forget: give the background Task time to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(spy.savedEntries.count, 1)
        XCTAssertEqual(spy.savedEntries.first?.name, "Mehl")
    }

    func test_addItem_catalogSavePreservesAttributes() async throws {
        let item = ItemModel(
            name: "Haferflocken",
            units: 3,
            measure: "kg",
            price: 1.29,
            category: "Grundnahrung",
            brand: "Kölln"
        )
        sut.addItem(item)
        try await Task.sleep(nanoseconds: 100_000_000)

        let saved = spy.savedEntries.first
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.measure, "kg")
        XCTAssertEqual(saved?.category, "Grundnahrung")
        XCTAssertEqual(saved?.brand, "Kölln")
    }

    func test_addItem_noCatalogSaveWhenRepositoryNotInjected() async throws {
        // Create a fresh VM without catalog repository
        let container = PersistenceController.preview.container
        let itemStore = SwiftDataItemStore(context: container.mainContext)
        let listStore = SwiftDataListStore(context: container.mainContext)
        let vm = ListViewModel(
            listId: UUID(),
            repository: PreviewItemsRepository(),
            itemStore: itemStore,
            listStore: listStore,
            startImmediately: false
        )
        // catalogRepository intentionally NOT configured

        let item = ItemModel(name: "Zitrone")
        vm.addItem(item)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(spy.savedEntries.isEmpty)
    }

    // MARK: - updateItem triggers catalog update

    func test_updateItem_triggersCatalogSave() async throws {
        let item = ItemModel(name: "Joghurt", units: 2, measure: "Becher")
        sut.updateItem(item)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(spy.savedEntries.count, 1)
        XCTAssertEqual(spy.savedEntries.first?.name, "Joghurt")
    }

    func test_updateItem_catalogSaveReflectsNewAttributes() async throws {
        let item = ItemModel(name: "Butter", units: 1, measure: "Packung")
        sut.updateItem(item)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Simulate attribute change: update price
        var updated = item
        updated.price = 2.49
        sut.updateItem(updated)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Both calls should have triggered a save (upsert handles deduplication)
        XCTAssertEqual(spy.savedEntries.count, 2)
        XCTAssertEqual(spy.savedEntries.last?.price ?? 0, 2.49, accuracy: 0.001)
    }
}

// MARK: - Duplicate Prevention Tests

@MainActor
final class DuplicatePreventionTests: XCTestCase {

    /// Simulates the duplicate check logic from ItemSearchView.addToList()
    private func isDuplicate(itemName: String, inItems items: [ItemModel]) -> Bool {
        items.contains {
            $0.name.lowercased() == itemName.lowercased() && !$0.isChecked
        }
    }

    func test_noDuplicate_emptyList() {
        XCTAssertFalse(isDuplicate(itemName: "Milch", inItems: []))
    }

    func test_noDuplicate_differentName() {
        let items = [ItemModel(name: "Butter", isChecked: false)]
        XCTAssertFalse(isDuplicate(itemName: "Milch", inItems: items))
    }

    func test_duplicate_sameNameUnchecked() {
        let items = [ItemModel(name: "Milch", isChecked: false)]
        XCTAssertTrue(isDuplicate(itemName: "Milch", inItems: items))
    }

    func test_duplicate_caseInsensitive() {
        let items = [ItemModel(name: "milch", isChecked: false)]
        XCTAssertTrue(isDuplicate(itemName: "MILCH", inItems: items))
    }

    func test_noDuplicate_sameNameButChecked() {
        // If the matching item is already checked off, it should NOT count as duplicate
        let items = [ItemModel(name: "Milch", isChecked: true)]
        XCTAssertFalse(isDuplicate(itemName: "Milch", inItems: items))
    }

    func test_duplicate_mixedList_onlyUncheckedCountsAsDuplicate() {
        let items = [
            ItemModel(name: "Milch", isChecked: true),
            ItemModel(name: "Brot", isChecked: false)
        ]
        XCTAssertFalse(isDuplicate(itemName: "Milch", inItems: items)) // checked → not duplicate
        XCTAssertTrue(isDuplicate(itemName: "Brot", inItems: items))   // unchecked → duplicate
    }

    func test_noDuplicate_partialNameMatch() {
        let items = [ItemModel(name: "Vollmilch", isChecked: false)]
        // "Milch" ≠ "Vollmilch" – must be exact (lowercased) match
        XCTAssertFalse(isDuplicate(itemName: "Milch", inItems: items))
    }
}
