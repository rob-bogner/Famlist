/*
 GlobalProductCatalogTests.swift
 FamlistTests

 Famlist
 Created on: 14.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for the OpenFoodFacts global product catalog integration.

 🛠 Includes:
 - GlobalProductEntryTests: Codable roundtrip, toItemCatalogEntry() mapping.
 - PreviewGlobalProductCatalogRepositoryTests: search, case insensitivity, max results, empty search.
 - ItemSearchViewModelMergeTests: personal-first, dedup by name_lower, nil global repo, error fallback.
 - SearchResultTests: Identifiable, source flag, imageUrl behaviour.

 🔰 Notes for Beginners:
 - Uses XCTest with @MainActor for thread-safe ViewModel testing.
 - StubGlobalProductCatalogRepository simulates server errors for offline-first tests.

 📝 Last Change:
 - Initial creation for OpenFoodFacts integration tests.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

// MARK: - Stub

/// Stub for GlobalProductCatalogRepository — returns configured results or throws.
@MainActor
final class StubGlobalProductCatalogRepository: GlobalProductCatalogRepository {
    var stubbedResults: [GlobalProductEntry] = []
    var shouldThrow = false

    func search(query: String) async throws -> [GlobalProductEntry] {
        if shouldThrow { throw URLError(.badServerResponse) }
        return stubbedResults
    }
}

// MARK: - Helpers

private func makeGlobalEntry(
    code: String = UUID().uuidString,
    name: String,
    brand: String? = nil,
    imageUrl: String? = nil,
    scansN: Int = 100
) -> GlobalProductEntry {
    GlobalProductEntry(id: code, name: name, brand: brand, category: nil, measure: nil, imageUrl: imageUrl, scansN: scansN)
}

private func makePersonalEntry(name: String, brand: String? = nil) -> ItemCatalogEntry {
    ItemCatalogEntry(
        id: UUID().uuidString, ownerPublicId: "owner",
        name: name, brand: brand, category: nil, productDescription: nil,
        measure: "Stück", price: 0.0, imageData: nil
    )
}

// MARK: - GlobalProductEntry Tests

@MainActor
final class GlobalProductEntryTests: XCTestCase {

    // MARK: - Codable Roundtrip

    func test_codable_roundtrip() throws {
        let entry = GlobalProductEntry(
            id: "4008400401690",
            name: "Haribo Goldbären",
            brand: "Haribo",
            category: "Süßigkeiten",
            measure: "200 g",
            imageUrl: "https://images.openfoodfacts.org/images/products/foo.jpg",
            scansN: 180_000
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(GlobalProductEntry.self, from: encoded)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.name, entry.name)
        XCTAssertEqual(decoded.brand, entry.brand)
        XCTAssertEqual(decoded.category, entry.category)
        XCTAssertEqual(decoded.measure, entry.measure)
        XCTAssertEqual(decoded.imageUrl, entry.imageUrl)
        XCTAssertEqual(decoded.scansN, entry.scansN)
    }

    func test_codable_encodesCodeKeyAsCode() throws {
        let entry = GlobalProductEntry(id: "123456", name: "Test", brand: nil, category: nil, measure: nil, imageUrl: nil, scansN: 0)
        let data = try JSONEncoder().encode(entry)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // The CodingKey maps `id` → "code"; the JSON must contain "code", not "id"
        XCTAssertNotNil(json?["code"])
        XCTAssertNil(json?["id"])
    }

    // MARK: - toItemCatalogEntry()

    func test_toItemCatalogEntry_mapsFields() {
        let entry = GlobalProductEntry(
            id: "9001010101010",
            name: "Manner Schnitten",
            brand: "Manner",
            category: "Gebäck",
            measure: "75 g",
            imageUrl: "https://example.com/image.jpg",
            scansN: 60_000
        )

        let catalogEntry = entry.toItemCatalogEntry(ownerPublicId: "owner-1")

        XCTAssertEqual(catalogEntry.name, "Manner Schnitten")
        XCTAssertEqual(catalogEntry.brand, "Manner")
        XCTAssertEqual(catalogEntry.category, "Gebäck")
        XCTAssertEqual(catalogEntry.measure, "75 g")
        XCTAssertEqual(catalogEntry.ownerPublicId, "owner-1")
    }

    func test_toItemCatalogEntry_priceIsZero() {
        let entry = makeGlobalEntry(name: "Nutella")
        let catalogEntry = entry.toItemCatalogEntry(ownerPublicId: "")
        XCTAssertEqual(catalogEntry.price, 0.0, accuracy: 0.001)
    }

    func test_toItemCatalogEntry_imageDataIsNil() {
        let entry = makeGlobalEntry(name: "Nutella")
        let catalogEntry = entry.toItemCatalogEntry(ownerPublicId: "")
        XCTAssertNil(catalogEntry.imageData)
    }

    func test_toItemCatalogEntry_generatesNewUUID() {
        let entry = makeGlobalEntry(name: "Milch")
        let e1 = entry.toItemCatalogEntry(ownerPublicId: "")
        let e2 = entry.toItemCatalogEntry(ownerPublicId: "")
        XCTAssertNotEqual(e1.id, e2.id)
    }

    func test_toItemCatalogEntry_nilMeasureFallsBackToEmpty() {
        let entry = GlobalProductEntry(id: "1", name: "Apfel", brand: nil, category: nil, measure: nil, imageUrl: nil, scansN: 10)
        let catalogEntry = entry.toItemCatalogEntry(ownerPublicId: "")
        XCTAssertEqual(catalogEntry.measure, "")
    }
}

// MARK: - PreviewGlobalProductCatalogRepository Tests

@MainActor
final class PreviewGlobalProductCatalogRepositoryTests: XCTestCase {

    var repo: PreviewGlobalProductCatalogRepository!

    override func setUp() async throws {
        repo = PreviewGlobalProductCatalogRepository()
    }

    func test_search_returnsMatchingProducts() async throws {
        let results = try await repo.search(query: "Nutella")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.name.lowercased().contains("nutella") })
    }

    func test_search_isCaseInsensitive() async throws {
        let lower = try await repo.search(query: "nutella")
        let upper = try await repo.search(query: "NUTELLA")
        XCTAssertEqual(lower.map(\.id).sorted(), upper.map(\.id).sorted())
    }

    func test_search_returnsAtMostFiveResults() async throws {
        // All preview entries match an empty-ish broad query
        let results = try await repo.search(query: "a")
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    func test_search_returnsEmptyForNoMatch() async throws {
        let results = try await repo.search(query: "xyzNichtGefunden")
        XCTAssertTrue(results.isEmpty)
    }

    func test_search_sortedByScansDescending() async throws {
        let results = try await repo.search(query: "a")
        let scans = results.map(\.scansN)
        XCTAssertEqual(scans, scans.sorted(by: >))
    }
}

// MARK: - ItemSearchViewModel Merge Tests

@MainActor
final class ItemSearchViewModelMergeTests: XCTestCase {

    var sut: ItemSearchViewModel!
    var personalSpy: SpyItemCatalogRepository!
    var globalStub: StubGlobalProductCatalogRepository!

    override func setUp() async throws {
        personalSpy = SpyItemCatalogRepository()
        globalStub = StubGlobalProductCatalogRepository()
        sut = ItemSearchViewModel(
            catalogRepository: personalSpy,
            globalCatalogRepository: globalStub
        )
    }

    // MARK: - Personal First

    func test_merge_personalResultsAppearFirst() {
        let personal = [makePersonalEntry(name: "Milch"), makePersonalEntry(name: "Butter")]
        let global = [makeGlobalEntry(name: "Brot"), makeGlobalEntry(name: "Käse")]

        let merged = sut.merge(personal: personal, global: global)

        XCTAssertEqual(merged[0].source, .personal)
        XCTAssertEqual(merged[1].source, .personal)
        XCTAssertEqual(merged[2].source, .global)
    }

    // MARK: - Dedup by name_lower

    func test_merge_deduplicatesByNameCaseInsensitive() {
        let personal = [makePersonalEntry(name: "Milch")]
        let global = [makeGlobalEntry(name: "milch"), makeGlobalEntry(name: "Butter")]

        let merged = sut.merge(personal: personal, global: global)

        // "milch" from global must be excluded (same lowercased name as personal "Milch")
        XCTAssertFalse(merged.contains { $0.source == .global && $0.entry.name.lowercased() == "milch" })
        XCTAssertEqual(merged.count, 2) // personal "Milch" + global "Butter"
    }

    // MARK: - Max 5 Total

    func test_merge_maxFiveResultsTotal() {
        let personal = (1...4).map { makePersonalEntry(name: "Personal\($0)") }
        let global = (1...5).map { makeGlobalEntry(name: "Global\($0)") }

        let merged = sut.merge(personal: personal, global: global)

        XCTAssertLessThanOrEqual(merged.count, 5)
    }

    func test_merge_exactlyFiveWhenEnoughFromBothSources() {
        let personal = (1...3).map { makePersonalEntry(name: "P\($0)") }
        let global = (1...3).map { makeGlobalEntry(name: "G\($0)") }

        let merged = sut.merge(personal: personal, global: global)

        XCTAssertEqual(merged.count, 5)
    }

    func test_merge_fivePersonalFillsAllSlots() {
        let personal = (1...5).map { makePersonalEntry(name: "P\($0)") }
        let global = (1...5).map { makeGlobalEntry(name: "G\($0)") }

        let merged = sut.merge(personal: personal, global: global)

        XCTAssertEqual(merged.count, 5)
        XCTAssertTrue(merged.allSatisfy { $0.source == .personal })
    }

    // MARK: - Nil global repository

    func test_merge_nilGlobalRepoReturnsOnlyPersonal() {
        // Create VM without global repo
        let vmNoGlobal = ItemSearchViewModel(catalogRepository: personalSpy)
        let personal = [makePersonalEntry(name: "Brot")]

        let merged = vmNoGlobal.merge(personal: personal, global: [])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.source, .personal)
    }

    // MARK: - Error fallback (offline-first)

    func test_performSearch_globalErrorReturnsOnlyPersonal() async throws {
        personalSpy.stubbedResults = [makePersonalEntry(name: "Milch")]
        globalStub.shouldThrow = true

        sut.searchText = "Milch"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000) // wait for debounce + search

        // Personal results should still appear despite global error
        XCTAssertFalse(sut.results.isEmpty)
        XCTAssertTrue(sut.results.allSatisfy { $0.source == .personal })
        XCTAssertNil(sut.errorMessage) // no error shown to user for global failure
    }

    func test_performSearch_personalErrorShowsError() async throws {
        personalSpy.shouldThrow = true
        globalStub.stubbedResults = [makeGlobalEntry(name: "Milch")]

        sut.searchText = "Milch"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - imageUrl behaviour

    func test_merge_personalResultsHaveNilImageUrl() {
        let personal = [makePersonalEntry(name: "Milch")]
        let merged = sut.merge(personal: personal, global: [])

        XCTAssertNil(merged.first?.imageUrl)
    }

    func test_merge_globalResultsCarryImageUrl() {
        let global = [makeGlobalEntry(name: "Nutella", imageUrl: "https://example.com/img.jpg")]
        let merged = sut.merge(personal: [], global: global)

        XCTAssertEqual(merged.first?.imageUrl, "https://example.com/img.jpg")
    }

    func test_merge_globalResultsWithNilImageUrlAreAllowed() {
        let global = [makeGlobalEntry(name: "Apfel", imageUrl: nil)]
        let merged = sut.merge(personal: [], global: global)

        XCTAssertEqual(merged.count, 1)
        XCTAssertNil(merged.first?.imageUrl)
    }
}

// MARK: - SearchResult Tests

@MainActor
final class SearchResultTests: XCTestCase {

    func test_identifiable_usesEntryId() {
        let entry = makePersonalEntry(name: "Butter")
        let result = SearchResult(entry: entry, source: .personal, imageUrl: nil)
        XCTAssertEqual(result.id, entry.id)
    }

    func test_equatable_sameResultsAreEqual() {
        let entry = makePersonalEntry(name: "Milch")
        let r1 = SearchResult(entry: entry, source: .personal, imageUrl: nil)
        let r2 = SearchResult(entry: entry, source: .personal, imageUrl: nil)
        XCTAssertEqual(r1, r2)
    }

    func test_equatable_differentSourceNotEqual() {
        let entry = makePersonalEntry(name: "Milch")
        let r1 = SearchResult(entry: entry, source: .personal, imageUrl: nil)
        let r2 = SearchResult(entry: entry, source: .global, imageUrl: nil)
        XCTAssertNotEqual(r1, r2)
    }

    func test_equatable_differentImageUrlNotEqual() {
        let entry = makePersonalEntry(name: "Milch")
        let r1 = SearchResult(entry: entry, source: .global, imageUrl: "https://a.com/img.jpg")
        let r2 = SearchResult(entry: entry, source: .global, imageUrl: nil)
        XCTAssertNotEqual(r1, r2)
    }

    func test_sourceFlagPersonal() {
        let result = SearchResult(entry: makePersonalEntry(name: "Butter"), source: .personal, imageUrl: nil)
        XCTAssertEqual(result.source, .personal)
    }

    func test_sourceFlagGlobal() {
        let result = SearchResult(entry: makePersonalEntry(name: "Butter"), source: .global, imageUrl: nil)
        XCTAssertEqual(result.source, .global)
    }
}
