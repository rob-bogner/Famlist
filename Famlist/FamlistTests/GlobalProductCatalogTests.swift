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
 - ItemSearchViewModelMergeTests: separate personalResults / globalResults, nil global repo, error fallback.
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

// MARK: - ItemSearchViewModel Search Tests

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

    // MARK: - Separate Collections

    func test_performSearch_populatesPersonalResults() async throws {
        personalSpy.stubbedResults = [makePersonalEntry(name: "Milch"), makePersonalEntry(name: "Butter")]
        globalStub.stubbedResults = []

        sut.searchText = "Mi"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(sut.personalResults.count, 2)
        XCTAssertTrue(sut.personalResults.allSatisfy { $0.source == .personal })
        XCTAssertTrue(sut.globalResults.isEmpty)
    }

    func test_performSearch_populatesGlobalResults() async throws {
        personalSpy.stubbedResults = []
        globalStub.stubbedResults = [makeGlobalEntry(name: "Brot"), makeGlobalEntry(name: "Käse")]

        sut.searchText = "Br"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(sut.personalResults.isEmpty)
        XCTAssertEqual(sut.globalResults.count, 2)
        XCTAssertTrue(sut.globalResults.allSatisfy { $0.source == .global })
    }

    func test_performSearch_bothCollectionsPopulatedIndependently() async throws {
        personalSpy.stubbedResults = [makePersonalEntry(name: "Milch")]
        globalStub.stubbedResults = [makeGlobalEntry(name: "Milch"), makeGlobalEntry(name: "Butter")]

        sut.searchText = "Mi"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        // No dedup across collections — both show all results independently
        XCTAssertEqual(sut.personalResults.count, 1)
        XCTAssertEqual(sut.globalResults.count, 2)
    }

    // MARK: - Personal cap (max 5)

    func test_performSearch_personalCappedAtFive() async throws {
        personalSpy.stubbedResults = (1...8).map { makePersonalEntry(name: "P\($0)") }
        globalStub.stubbedResults = []

        sut.searchText = "PP"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertLessThanOrEqual(sut.personalResults.count, 5)
    }

    func test_performSearch_globalNotCappedByPersonalSlots() async throws {
        personalSpy.stubbedResults = (1...5).map { makePersonalEntry(name: "P\($0)") }
        globalStub.stubbedResults = (1...6).map { makeGlobalEntry(name: "G\($0)") }

        sut.searchText = "PP"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        // Global results are independent — full 6 should appear
        XCTAssertEqual(sut.globalResults.count, 6)
        XCTAssertLessThanOrEqual(sut.personalResults.count, 5)
    }

    // MARK: - Nil global repository

    func test_performSearch_nilGlobalRepoLeavesGlobalEmpty() async throws {
        let vmNoGlobal = ItemSearchViewModel(catalogRepository: personalSpy)
        personalSpy.stubbedResults = [makePersonalEntry(name: "Brot")]

        vmNoGlobal.searchText = "Br"
        vmNoGlobal.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vmNoGlobal.personalResults.count, 1)
        XCTAssertTrue(vmNoGlobal.globalResults.isEmpty)
    }

    // MARK: - Error fallback (offline-first)

    func test_performSearch_globalErrorReturnsOnlyPersonal() async throws {
        personalSpy.stubbedResults = [makePersonalEntry(name: "Milch")]
        globalStub.shouldThrow = true

        sut.searchText = "Milch"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        // Personal results should still appear despite global error
        XCTAssertFalse(sut.personalResults.isEmpty)
        XCTAssertTrue(sut.personalResults.allSatisfy { $0.source == .personal })
        XCTAssertNil(sut.errorMessage) // no error shown to user for global failure
    }

    func test_performSearch_personalErrorShowsError() async throws {
        personalSpy.shouldThrow = true
        globalStub.stubbedResults = [makeGlobalEntry(name: "Milch")]

        sut.searchText = "Milch"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(sut.personalResults.isEmpty)
        XCTAssertTrue(sut.globalResults.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - imageUrl behaviour

    func test_performSearch_personalResultsHaveNilImageUrl() async throws {
        personalSpy.stubbedResults = [makePersonalEntry(name: "Milch")]
        globalStub.stubbedResults = []

        sut.searchText = "Mi"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNil(sut.personalResults.first?.imageUrl)
    }

    func test_performSearch_globalResultsCarryImageUrl() async throws {
        personalSpy.stubbedResults = []
        globalStub.stubbedResults = [makeGlobalEntry(name: "Nutella", imageUrl: "https://example.com/img.jpg")]

        sut.searchText = "Nu"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(sut.globalResults.first?.imageUrl, "https://example.com/img.jpg")
    }

    func test_performSearch_globalResultsWithNilImageUrlAreAllowed() async throws {
        personalSpy.stubbedResults = []
        globalStub.stubbedResults = [makeGlobalEntry(name: "Apfel", imageUrl: nil)]

        sut.searchText = "Ap"
        sut.onSearchTextChanged()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(sut.globalResults.count, 1)
        XCTAssertNil(sut.globalResults.first?.imageUrl)
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
