/*
 ManageItemsAndBarcodeTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Artikel verwalten“ (Filter, Suche, Löschen mit Rücknahme) und die Barcode-Suche
   (eigener Artikelstamm vor Open-Food-Facts, unbekannte Codes).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
private final class StubCatalog: ItemCatalogRepository {
    var entries: [ItemCatalogEntry]
    var failDelete = false
    init(_ entries: [ItemCatalogEntry]) { self.entries = entries }
    func search(query: String) async throws -> [ItemCatalogEntry] { [] }
    func save(_ entry: ItemCatalogEntry) async throws { entries.append(entry) }
    func fetchAll() async throws -> [ItemCatalogEntry] { entries }
    func delete(id: String) async throws {
        if failDelete { throw URLError(.notConnectedToInternet) }
        entries.removeAll { $0.id == id }
    }
    func find(barcode: String) async throws -> ItemCatalogEntry? { entries.first { $0.barcode == barcode } }
}

/// Artikelstamm, dessen Schreiben erst nach einer Pause beim „Server“ ankommt (wie im Netz).
@MainActor
private final class SlowCatalog: ItemCatalogRepository {
    var entries: [ItemCatalogEntry]
    init(_ entries: [ItemCatalogEntry]) { self.entries = entries }
    func search(query: String) async throws -> [ItemCatalogEntry] { [] }
    func save(_ entry: ItemCatalogEntry) async throws { entries.append(entry) }
    func fetchAll() async throws -> [ItemCatalogEntry] { entries }
    func update(_ entry: ItemCatalogEntry) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        if let i = entries.firstIndex(where: { $0.id == entry.id }) { entries[i] = entry }
    }
}

@MainActor
private final class StubGlobal: GlobalProductCatalogRepository {
    let products: [GlobalProductEntry]
    init(_ products: [GlobalProductEntry]) { self.products = products }
    func search(query: String) async throws -> [GlobalProductEntry] { [] }
    func product(code: String) async throws -> GlobalProductEntry? { products.first { $0.id == code } }
}

@MainActor
final class ManageItemsAndBarcodeTests: XCTestCase {
    /// Wartet, bis `condition` erfüllt ist (höchstens 2 s) – statt fester Pausen, die unter Last zu kurz sind.
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    private func entry(_ name: String, _ category: ItemCategory?, brand: String? = nil,
                       barcode: String? = nil) -> ItemCatalogEntry {
        ItemCatalogEntry(id: name, ownerPublicId: "me", name: name, brand: brand, category: category?.rawValue,
                         productDescription: nil, measure: "", price: 0, imageData: nil, barcode: barcode)
    }

    // MARK: - Artikel verwalten

    func test_filters_allPlusPresentCategoriesInStoreOrder() async {
        let vm = ManageItemsViewModel(repository: StubCatalog([entry("Brot", .backwaren), entry("Äpfel", .obstGemuese)]))
        await vm.load()
        XCTAssertEqual(vm.filters, ["Alle", ItemCategory.obstGemuese.rawValue, ItemCategory.backwaren.rawValue])
    }

    func test_filterAndQuery_narrowEntries() async {
        let vm = ManageItemsViewModel(repository: StubCatalog([
            entry("Vollmilch", .milch), entry("Hafermilch", .getraenke, brand: "Oatly"), entry("Brot", .backwaren)]))
        await vm.load()
        vm.query = "milch"
        XCTAssertEqual(vm.visibleEntries.map(\.name), ["Vollmilch", "Hafermilch"])
        vm.selectedFilter = ItemCategory.milch.rawValue
        XCTAssertEqual(vm.visibleEntries.map(\.name), ["Vollmilch"])
        vm.selectedFilter = ManageItemsViewModel.allFilter
        vm.query = "oatly"
        XCTAssertEqual(vm.visibleEntries.map(\.name), ["Hafermilch"], "Suche findet auch die Marke")
    }

    func test_delete_removesOptimistically_andRestoresOnError() async throws {
        let catalog = StubCatalog([entry("Brot", .backwaren), entry("Milch", .milch)])
        catalog.failDelete = true
        let vm = ManageItemsViewModel(repository: catalog)
        await vm.load()
        vm.delete(vm.entries[0])
        XCTAssertEqual(vm.entries.map(\.name), ["Milch"])
        await waitUntil { vm.errorMessage != nil }
        XCTAssertEqual(vm.entries.map(\.name), ["Brot", "Milch"])
        XCTAssertNotNil(vm.errorMessage)
    }

    /// Gerätefehler: Maßeinheit geändert → „Artikel verwalten“ lädt beim Zurückkehren neu → alte Einheit war wieder da.
    func test_update_thenImmediateReload_keepsChange() async {
        let catalog = SlowCatalog([entry("Butter", .milch)])
        let vm = ManageItemsViewModel(repository: catalog)
        await vm.load()
        var changed = vm.entries[0]
        changed.measure = "Packung"
        vm.update(changed)
        await vm.load()
        XCTAssertEqual(vm.entries.first?.measure, "Packung", "Neuladen darf die Änderung nicht überschreiben")
        XCTAssertEqual(catalog.entries.first?.measure, "Packung")
    }

    func test_twoQuickUpdates_arriveInOrder() async {
        let catalog = SlowCatalog([entry("Butter", .milch)])
        let vm = ManageItemsViewModel(repository: catalog)
        await vm.load()
        var first = vm.entries[0]; first.measure = "g"
        var second = first; second.measure = "kg"
        vm.update(first)
        vm.update(second)
        await vm.load()
        XCTAssertEqual(catalog.entries.first?.measure, "kg")
        XCTAssertEqual(vm.entries.first?.measure, "kg")
    }

    func test_meta_prefersBrand_elseCategory() {
        XCTAssertEqual(ManageItemsViewModel.meta(for: entry("Butter", .sonstiges, brand: "Kerrygold")), "Kerrygold")
        XCTAssertEqual(ManageItemsViewModel.meta(for: entry("Butter", .sonstiges)), ItemCategory.sonstiges.rawValue)
    }

    // MARK: - Barcode

    func test_barcode_ownCatalogWinsOverGlobal() async {
        let own = entry("Meine Butter", .milch, barcode: "400")
        let global = GlobalProductEntry(id: "400", name: "OFF Butter", brand: "X", category: nil, measure: "250 g",
                                        imageUrl: nil, scansN: 1)
        let vm = BarcodeScanViewModel(catalog: StubCatalog([own]), global: StubGlobal([global]))
        let unknown = await vm.handle(code: "400")
        XCTAssertNil(unknown)
        guard case .found(let product) = vm.state else { return XCTFail("kein Treffer") }
        XCTAssertEqual(product.entry.name, "Meine Butter")
    }

    func test_barcode_globalHit_carriesBarcodeAndMeta() async {
        let global = GlobalProductEntry(id: "500", name: "Kerrygold Butter", brand: "Kerrygold", category: nil,
                                        measure: "250 g", imageUrl: nil, scansN: 1)
        let vm = BarcodeScanViewModel(catalog: StubCatalog([]), global: StubGlobal([global]))
        _ = await vm.handle(code: "500")
        guard case .found(let product) = vm.state else { return XCTFail("kein Treffer") }
        XCTAssertEqual(product.entry.barcode, "500")
        XCTAssertEqual(product.meta, "Kerrygold · 250 g")
    }

    func test_barcode_unknown_returnsCode_andKeepsScanning() async {
        let vm = BarcodeScanViewModel(catalog: StubCatalog([]), global: StubGlobal([]))
        let unknown = await vm.handle(code: "999")
        XCTAssertEqual(unknown, "999")
        XCTAssertEqual(vm.state, .scanning)
    }

    func test_quantity_cyclesOneToNine() {
        let vm = BarcodeScanViewModel(catalog: nil, global: nil)
        for _ in 0..<9 { vm.cycleQuantity() }
        XCTAssertEqual(vm.quantity, 1)
    }
}
