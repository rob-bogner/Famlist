/*
 ReceiptItemPriceTests.swift
 FamlistTests

 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Preise übernehmen“ nach dem Kassenzettel: neue Preise in der Liste und im Artikelstamm.

 🔰 Notes for Beginners:
 - SwiftData nur im Speicher; Artikelstamm = PreviewItemCatalogRepository (im Speicher).
 - Ohne SyncEngine zeigt `items` die Änderung sofort (applyLocalEdit), gesendet wird nichts.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftData
import XCTest
@testable import Famlist

@MainActor
final class ReceiptItemPriceTests: XCTestCase {
    private func makeViewModel() throws -> ListViewModel {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        return ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                             itemStore: SwiftDataItemStore(context: context),
                             listStore: SwiftDataListStore(context: context), startImmediately: false)
    }

    func test_receiptPriceUpdates_onlyMatchingAndChangedItems() {
        let items = [ItemModel(id: "1", name: "Butter ", units: 2, measure: "", price: 1.89, isChecked: true),
                     ItemModel(id: "2", name: "Milch", units: 1, measure: "", price: 1.19),
                     ItemModel(id: "3", name: "Brot", units: 1, measure: "", price: 2.99)]
        let updates = ListViewModel.receiptPriceUpdates(for: items, prices: ["butter": 2.49, "milch": 1.19])
        XCTAssertEqual(updates.map(\.id), ["1"], "Milch hat schon den Preis, Brot steht nicht auf dem Bon")
        XCTAssertEqual(updates[0].price, 2.49, accuracy: 0.001)
        XCTAssertEqual(updates[0].units, 2, "Menge bleibt")
        XCTAssertTrue(updates[0].isChecked, "Abhak-Status bleibt")
    }

    func test_applyReceiptPrices_updatesListAndCatalog() async throws {
        let vm = try makeViewModel()
        let catalog = PreviewItemCatalogRepository()          // enthält „Butter“ zu 1,89 € und „Milch“ zu 1,49 €
        vm.configure(catalogRepository: catalog)
        vm.items = [ItemModel(id: "1", name: "Butter", units: 1, measure: "", price: 1.89)]

        let changed = await vm.applyReceiptPrices([ReceiptPriceChange(name: "butter", price: 2.49),
                                                   ReceiptPriceChange(name: "Milch", price: 1.49)])

        XCTAssertEqual(changed, 1, "Butter in Liste und Artikelstamm zählt einmal; Milch hat schon 1,49 €")
        XCTAssertEqual(vm.items.first?.price ?? 0, 2.49, accuracy: 0.001)
        let entries = try await catalog.fetchAll()
        XCTAssertEqual(entries.first { $0.name == "Butter" }?.price ?? 0, 2.49, accuracy: 0.001)
        XCTAssertEqual(entries.first { $0.name == "Milch" }?.price ?? 0, 1.49, accuracy: 0.001)
    }

    func test_applyReceiptPrices_empty_changesNothing() async throws {
        let vm = try makeViewModel()
        vm.items = [ItemModel(id: "1", name: "Butter", units: 1, measure: "", price: 1.89)]
        let changed = await vm.applyReceiptPrices([])
        XCTAssertEqual(changed, 0)
        XCTAssertEqual(vm.items.first?.price ?? 0, 1.89, accuracy: 0.001)
    }
}
