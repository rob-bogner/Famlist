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

    func test_emptyAccount_seedsEightDefaults_andSavesThem() async throws {
        let repo = InMemoryCategoryDefinitionsRepository()
        let store = await makeStore(repo)
        XCTAssertEqual(store.categories.map(\.name), ItemCategory.displayOrder.map(\.rawValue))
        await waitUntil { repo.stored.count == 8 }
        XCTAssertEqual(repo.stored.count, 8)
    }

    func test_add_insertsBeforeFallback_rejectsDuplicates() async {
        let store = await makeStore()
        XCTAssertTrue(store.add(name: "Drogerie", icon: "bag"))
        XCTAssertFalse(store.add(name: "drogerie", icon: "bag"), "Groß/Klein egal")
        XCTAssertFalse(store.add(name: "  ", icon: "bag"))
        XCTAssertEqual(store.categories.suffix(2).map(\.name), ["Drogerie", "Sonstiges"])
        XCTAssertEqual(store.categories.map(\.position), Array(0..<store.categories.count))
    }

    func test_update_returnsOldName_onlyWhenRenamed() async {
        let store = await makeStore()
        let milk = store.categories[1]
        XCTAssertNil(store.update(milk.id, name: milk.name, icon: "cup"), "nur Icon geändert")
        XCTAssertEqual(store.update(milk.id, name: "Molkerei", icon: "cup"), "Milchprodukte")
        XCTAssertEqual(store.categories[1].name, "Molkerei")
    }

    func test_fallback_cannotBeDeletedOrRenamed() async {
        let store = await makeStore()
        let fallback = store.categories.first(where: \.isFallback)!
        XCTAssertNil(store.delete(fallback.id))
        XCTAssertNil(store.update(fallback.id, name: "Rest", icon: "bag"))
        XCTAssertEqual(store.categories.first(where: \.isFallback)?.name, "Sonstiges")
    }

    func test_delete_returnsName() async {
        let store = await makeStore()
        let bread = store.categories[2]
        XCTAssertEqual(store.delete(bread.id), "Backwaren")
        XCTAssertFalse(store.categories.contains { $0.name == "Backwaren" })
    }

    func test_move_changesStoreRoute() async {
        let store = await makeStore()
        let bread = store.categories[2], fruit = store.categories[0]
        store.move(bread.id, to: fruit.id)
        XCTAssertEqual(store.categories.prefix(2).map(\.name), ["Backwaren", "Obst & Gemüse"])
        store.move(bread.id, by: 1)
        XCTAssertEqual(store.categories.prefix(2).map(\.name), ["Obst & Gemüse", "Backwaren"])
    }

    func test_cache_survivesWithoutRepository() async {
        let store = await makeStore()
        _ = store.add(name: "Drogerie", icon: "bag")
        let offline = CategoryStore(repository: nil, defaults: defaults)
        await offline.load(profileId: profileId)
        XCTAssertTrue(offline.categories.contains { $0.name == "Drogerie" })
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
}
