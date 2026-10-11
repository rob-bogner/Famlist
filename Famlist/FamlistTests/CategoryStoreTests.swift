/*
 CategoryStoreTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für Phase 6: Kategorien anlegen/umbenennen/löschen/umsortieren (CategoryStore), Zuordnung alter
   und unbekannter Namen (CategoryResolver) und das Mitziehen der Artikel (reassignCategory).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

/// Merkt sich, welche Artikel an die SyncEngine gehen (Speichern ist deren Aufgabe).
private final class SpySyncEngine: SyncEngineProtocol {
    var updated: [ItemModel] = []
    func createItem(_ item: ItemModel) async {}
    func updateItem(_ item: ItemModel) async { updated.append(item) }
    func deleteItem(_ item: ItemModel) async {}
    func resumeSync() async {}
    func retryItem(_ item: ItemModel) async {}
    func applyBulkItems(_ targets: [ImportTarget]) async {}
}

/// Kategorien-Server, der zwischen „offline“ und „online“ umgeschaltet werden kann.
/// @MainActor schützt den Schalter `offline`; so erfüllt die Klasse das Sendable-Protokoll.
@MainActor
private final class FlakyCategoriesRepository: CategoryDefinitionsRepository {
    var offline = false
    let inner = InMemoryCategoryDefinitionsRepository()
    func fetch(profileId: UUID) async throws -> [CategoryDefinition] {
        if offline { throw URLError(.notConnectedToInternet) }
        return try await inner.fetch(profileId: profileId)
    }
    func upsert(_ categories: [CategoryDefinition], profileId: UUID) async throws {
        if offline { throw URLError(.notConnectedToInternet) }
        try await inner.upsert(categories, profileId: profileId)
    }
    func delete(id: UUID) async throws {
        if offline { throw URLError(.notConnectedToInternet) }
        try await inner.delete(id: id)
    }
}

@MainActor
final class CategoryStoreTests: XCTestCase {
    /// Wartet, bis `condition` erfüllt ist (höchstens 2 s) – statt fester Pausen, die unter Last zu kurz sind.
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }
    private var defaults: UserDefaults!
    private let profileId = UUID()

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "CategoryStoreTests")
        defaults.removePersistentDomain(forName: "CategoryStoreTests")
    }

    private func makeStore(_ repo: InMemoryCategoryDefinitionsRepository = .init()) async -> CategoryStore {
        let store = CategoryStore(repository: repo, defaults: defaults)
        await store.load(profileId: profileId)
        return store
    }

    func test_emptyAccount_seedsAllDefaults_andSavesThem() async throws {
        let repo = InMemoryCategoryDefinitionsRepository()
        let store = await makeStore(repo)
        XCTAssertEqual(store.categories.map(\.name), ItemCategory.displayOrder.map(\.rawValue))
        await waitUntil { repo.stored.count == 27 }
        XCTAssertEqual(repo.stored.count, 27)
    }

    // MARK: - Standard-Kategorien (12.10.2026: 27 statt 8)

    func test_defaults_haveUniqueNames_knownIcons_andOwnPaletteColors() {
        let defs = CategoryDefinition.defaults
        XCTAssertEqual(defs.count, 27)
        XCTAssertEqual(Set(defs.map { $0.name.lowercased() }).count, defs.count, "Namen eindeutig (Groß/Klein egal)")
        XCTAssertEqual(defs.first?.name, "Obst & Gemüse")
        XCTAssertTrue(defs.last?.isFallback == true, "„Sonstiges“ steht am Ende")
        for def in defs {
            XCTAssertTrue(CategoryIconCatalog.allKeys.contains(def.icon), "\(def.name): Icon \(def.icon) fehlt im Raster")
            XCTAssertLessThanOrEqual(def.name.count, 100, "items_category_len")
        }
        let colors = defs.map { CategoryColor.hex(for: $0) }
        XCTAssertEqual(Set(colors).count, defs.count, "jede Standard-Kategorie hat eine eigene Farbe")
        XCTAssertTrue(colors.allSatisfy { hex in CategoryColor.palette.contains { $0.hex == hex } }, "nur Farben der Palette")
    }

    func test_originalEightCategories_keepNameIconAndColor() {
        let expected: [(String, String, String)] = [
            ("Obst & Gemüse", "apple", "#29C75D"), ("Milchprodukte", "milk", "#4799E1"), ("Backwaren", "bread", "#8F6F24"),
            ("Getränke", "bottle", "#29C7C2"), ("Haushalt", "spray", "#8F47E1"), ("Tiefkühl", "snowflake", "#475BE1"),
            ("Fleisch & Fisch", "meat", "#C72933"), ("Sonstiges", "tag", "#5E8D8B"),
        ]
        for (name, icon, color) in expected {
            let def = CategoryDefinition.defaults.first { $0.name == name }
            XCTAssertEqual(def?.icon, icon, name)
            XCTAssertEqual(def.map(CategoryColor.hex(for:)), color, name)
        }
    }

    func test_photoSuggestion_usesFineCategory_orCoarserOneOfOlderAccounts() {
        let all = ItemCategory.allCases.map(\.rawValue)
        let old = ["Obst & Gemüse", "Milchprodukte", "Backwaren", "Getränke", "Haushalt", "Tiefkühl", "Fleisch & Fisch", "Sonstiges"]
        XCTAssertEqual(ProductPhotoSuggester.categoryName(.kaese, userCategories: all), "Käse")
        XCTAssertEqual(ProductPhotoSuggester.categoryName(.kaese, userCategories: old), "Milchprodukte")
        XCTAssertEqual(ProductPhotoSuggester.categoryName(.wurst, userCategories: old), "Fleisch & Fisch")
        XCTAssertEqual(ProductPhotoSuggester.categoryName(.alkohol, userCategories: old), "Getränke")
        XCTAssertEqual(ProductPhotoSuggester.categoryName(.eier, userCategories: []), "Eier", "ohne bekannte Kategorien: fein")
        XCTAssertEqual(ProductPhotoSuggester.categoryName(.milch, userCategories: ["milchprodukte"]), "Milchprodukte")
    }

    func test_add_insertsBeforeFallback_rejectsDuplicates() async {
        let store = await makeStore()
        XCTAssertTrue(store.add(name: "Baumarkt", icon: "bag"))
        XCTAssertFalse(store.add(name: "baumarkt", icon: "bag"), "Groß/Klein egal")
        XCTAssertFalse(store.add(name: "  ", icon: "bag"))
        XCTAssertEqual(store.categories.suffix(2).map(\.name), ["Baumarkt", "Sonstiges"])
        XCTAssertEqual(store.categories.map(\.position), Array(0..<store.categories.count))
    }

    func test_update_returnsOldName_onlyWhenRenamed() async throws {
        let store = await makeStore()
        let milk = try XCTUnwrap(store.categories.first { $0.name == "Milchprodukte" })
        XCTAssertNil(store.update(milk.id, name: milk.name, icon: "cup"), "nur Icon geändert")
        XCTAssertEqual(store.update(milk.id, name: "Molkerei", icon: "cup"), "Milchprodukte")
        XCTAssertEqual(store.categories[milk.position].name, "Molkerei")
    }

    func test_color_isStoredAndKeptWhenNil() async throws {
        let store = await makeStore()
        let milk = try XCTUnwrap(store.categories.first { $0.name == "Milchprodukte" })
        XCTAssertEqual(CategoryColor.hex(for: milk), "#4799E1", "Standardfarbe Milchprodukte")
        _ = store.update(milk.id, name: milk.name, icon: milk.icon, color: "#C72933")
        XCTAssertEqual(store.categories[milk.position].color, "#C72933")
        _ = store.update(milk.id, name: milk.name, icon: "cup")
        XCTAssertEqual(store.categories[milk.position].color, "#C72933", "ohne Farbe bleibt die gewählte")
        XCTAssertTrue(store.add(name: "Baumarkt", icon: "bag", color: "#8F47E1"))
        XCTAssertEqual(store.categories.first { $0.name == "Baumarkt" }?.color, "#8F47E1")
        XCTAssertEqual(CategoryColor.palette.count, 36)
    }

    func test_fallback_cannotBeDeletedOrRenamed() async {
        let store = await makeStore()
        let fallback = store.categories.first(where: \.isFallback)!
        XCTAssertNil(store.delete(fallback.id))
        XCTAssertNil(store.update(fallback.id, name: "Rest", icon: "bag"))
        XCTAssertEqual(store.categories.first(where: \.isFallback)?.name, "Sonstiges")
    }

    func test_delete_returnsName() async throws {
        let store = await makeStore()
        let bread = try XCTUnwrap(store.categories.first { $0.name == "Backwaren" })
        XCTAssertEqual(store.delete(bread.id), "Backwaren")
        XCTAssertFalse(store.categories.contains { $0.name == "Backwaren" })
    }

    func test_move_changesStoreRoute() async {
        let store = await makeStore()
        let bread = store.categories[1], fruit = store.categories[0]
        store.move(bread.id, to: fruit.id)
        XCTAssertEqual(store.categories.prefix(2).map(\.name), ["Backwaren", "Obst & Gemüse"])
        store.move(bread.id, by: 1)
        XCTAssertEqual(store.categories.prefix(2).map(\.name), ["Obst & Gemüse", "Backwaren"])
    }

    func test_cache_survivesWithoutRepository() async {
        let store = await makeStore()
        _ = store.add(name: "Baumarkt", icon: "bag")
        let offline = CategoryStore(repository: nil, defaults: defaults)
        await offline.load(profileId: profileId)
        XCTAssertTrue(offline.categories.contains { $0.name == "Baumarkt" })
    }

    // MARK: - Resolver

    func test_resolver_exact_legacy_unknown_empty() {
        let defs = CategoryDefinition.defaults
        XCTAssertEqual(CategoryResolver.name(for: "milchprodukte", in: defs), "Milchprodukte")
        XCTAssertEqual(CategoryResolver.name(for: ItemCategory.milch.rawValue, in: defs), "Milchprodukte")
        XCTAssertEqual(CategoryResolver.name(for: "Gibt es nicht", in: defs), "Sonstiges")
        XCTAssertEqual(CategoryResolver.name(for: nil, in: defs), "Sonstiges")
    }

    // MARK: - Artikel mitziehen

    func test_reassignCategory_updatesItemsWithOldName() async throws {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let listId = UUID()
        let vm = ListViewModel(listId: listId, repository: PreviewItemsRepository(),
                               itemStore: SwiftDataItemStore(context: context),
                               listStore: SwiftDataListStore(context: context), startImmediately: false)
        let spy = SpySyncEngine()
        vm.configure(syncEngine: spy)
        for (name, category) in [("Milch", "Milchprodukte"), ("Käse", "Milchprodukte"), ("Brot", "Backwaren")] {
            vm.storePendingChange(for: ItemModel(id: UUID().uuidString, name: name, category: category,
                                                 listId: listId.uuidString), status: .pendingCreate)
        }
        let changed = vm.reassignCategory(from: "Milchprodukte", to: "Sonstiges")
        XCTAssertEqual(changed, 2)
        await waitUntil { spy.updated.count == 2 }
        XCTAssertEqual(Set(spy.updated.map(\.name)), ["Milch", "Käse"])
        XCTAssertTrue(spy.updated.allSatisfy { $0.category == "Sonstiges" })
    }

    // MARK: - Offline zuerst (Audit M4)

    func test_offlineChanges_stayLocal_andAreSentLater() async throws {
        let repo = FlakyCategoriesRepository()
        let store = CategoryStore(repository: repo, defaults: defaults)
        await store.load(profileId: profileId)
        await store.waitForWrites()
        repo.offline = true
        XCTAssertTrue(store.add(name: "Baumarkt", icon: "bag"))
        await store.waitForWrites()
        XCTAssertTrue(store.categories.contains { $0.name == "Baumarkt" })
        XCTAssertNil(store.errorMessage, "offline ist kein Fehler")
        XCTAssertFalse(repo.inner.stored.contains { $0.name == "Baumarkt" })

        // Neustart offline: die Änderung ist noch da
        let restarted = CategoryStore(repository: repo, defaults: defaults)
        await restarted.load(profileId: profileId)
        XCTAssertTrue(restarted.categories.contains { $0.name == "Baumarkt" })

        // Wieder online: beim Laden zuerst senden, dann übernehmen – nichts geht verloren
        repo.offline = false
        await restarted.load(profileId: profileId)
        await restarted.waitForWrites()
        XCTAssertTrue(repo.inner.stored.contains { $0.name == "Baumarkt" })
        XCTAssertTrue(restarted.categories.contains { $0.name == "Baumarkt" })
    }

    func test_offlineDelete_survivesRestart_andIsSentLater() async throws {
        let repo = FlakyCategoriesRepository()
        let store = CategoryStore(repository: repo, defaults: defaults)
        await store.load(profileId: profileId)
        await store.waitForWrites()
        let milk = try XCTUnwrap(store.categories.first { !$0.isFallback })
        repo.offline = true
        XCTAssertNotNil(store.delete(milk.id))
        await store.waitForWrites()

        repo.offline = false
        let restarted = CategoryStore(repository: repo, defaults: defaults)
        await restarted.load(profileId: profileId)
        await restarted.waitForWrites()
        XCTAssertFalse(repo.inner.stored.contains { $0.id == milk.id })
        XCTAssertFalse(restarted.categories.contains { $0.id == milk.id })
    }
}
