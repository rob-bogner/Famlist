/*
 ItemEditLocalUpdateTests.swift
 FamlistTests

 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression: Ein in „Artikel bearbeiten“ gespeicherter Preis ist sofort in `items` sichtbar.

 🔰 Notes for Beginners:
 - Vorher kam die Änderung erst nach der Netzwerk-Queue der SyncEngine an → der Preis blieb 0,00.
 - Ohne SyncEngine (startImmediately: false) prüft der Test genau den lokalen, sofortigen Teil.

 📝 Last Change:
 - Initial creation (Bugfix Preis speichern).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ItemEditLocalUpdateTests: XCTestCase {

    private var sut: ListViewModel!
    private let listId = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!

    override func setUp() async throws {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        sut = ListViewModel(listId: listId, repository: PreviewItemsRepository(),
                            itemStore: SwiftDataItemStore(context: context),
                            listStore: SwiftDataListStore(context: context), startImmediately: false)
    }

    override func tearDown() async throws {
        sut = nil
    }

    func test_updateItem_priceVisibleImmediately() {
        let butter = ItemModel(id: UUID().uuidString, name: "Butter", price: 0, listId: listId.uuidString)
        sut.items = [butter]
        var edited = butter
        edited.price = 2.49
        sut.updateItem(edited, updateCatalog: false)
        XCTAssertEqual(sut.items.first?.price, 2.49)
    }

    func test_updateItem_keepsSyncMetadata() {
        var butter = ItemModel(id: UUID().uuidString, name: "Butter", price: 0, listId: listId.uuidString)
        butter.hlcTimestamp = 42
        sut.items = [butter]
        var edited = butter
        edited.hlcTimestamp = nil                  // Formular kennt keine HLC-Felder
        edited.name = "Kerrygold Butter"
        sut.updateItem(edited, updateCatalog: false)
        XCTAssertEqual(sut.items.first?.name, "Kerrygold Butter")
        XCTAssertEqual(sut.items.first?.hlcTimestamp, 42, "CRDT-Felder bleiben unverändert")
    }

    // MARK: - Doppelt hinzufügen

    /// „Milch“ ist schon auf der Liste: Hinzufügen erhöht die Menge sofort sichtbar und übernimmt das Foto.
    func test_addItem_duplicate_incrementsUnitsAndTakesImage() {
        let milk = ItemModel(id: UUID().uuidString, name: "Milch", units: 1, measure: "pack", listId: listId.uuidString)
        sut.items = [milk]
        sut.addItem(ItemModel(imageData: "QUJD", name: "milch ", units: 1, price: 1.19, listId: listId.uuidString))
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.units, 2)
        XCTAssertEqual(sut.items.first?.imageData, "QUJD")
        XCTAssertEqual(sut.items.first?.price, 1.19)
    }

    func test_fillingMissingFields_keepsExistingValues() {
        let existing = ItemModel(imageData: "ALT", name: "Milch", units: 3, price: 0.99, brand: "Weihenstephan")
        let incoming = ItemModel(imageData: "NEU", name: "Milch", units: 1, price: 1.49, productDescription: "3,5 %", brand: "Andechser")
        let merged = ListViewModel.fillingMissingFields(of: existing, from: incoming)
        XCTAssertEqual(merged.imageData, "ALT")
        XCTAssertEqual(merged.price, 0.99)
        XCTAssertEqual(merged.brand, "Weihenstephan")
        XCTAssertEqual(merged.units, 3)
        XCTAssertEqual(merged.productDescription, "3,5 %")
    }
}
