/*
 PriceDisplayTests.swift
 FamlistTests

 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Preise anzeigen“ (Summe, Format) und den Preisverlauf mit nur einem Preis.

 🔰 Notes for Beginners:
 - Reine Logik, kein Netzwerk: PriceDisplaySetting und PriceHistoryViewModel.withFallback.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class PriceDisplayTests: XCTestCase {

    func test_total_multipliesPriceByUnits_andSkipsItemsWithoutPrice() {
        let items = [ItemModel(name: "Milch", units: 2, price: 1.49),
                     ItemModel(name: "Brot", units: 1, price: 2.99),
                     ItemModel(name: "Salz", units: 3, price: 0)]
        XCTAssertEqual(PriceDisplaySetting.total(of: items), 5.97, accuracy: 0.0001)
    }

    func test_euro_usesGermanFormat() {
        let text = PriceDisplaySetting.euro(1.49)
        XCTAssertTrue(text.contains("1,49"), text)
        XCTAssertTrue(text.contains("€"), text)
    }

    func test_history_withoutPoints_showsSavedPriceAsSinglePoint() {
        let entry = ItemCatalogEntry.from(item: ItemModel(name: "Milch", price: 1.49), ownerPublicId: "")
        let points = PriceHistoryViewModel.withFallback([], entry: entry, store: "Edeka")
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.storeName, "Edeka")
        XCTAssertEqual(points.first?.price, Decimal(string: "1.49"))
    }

    func test_history_withoutPointsAndPrice_staysEmpty() {
        let entry = ItemCatalogEntry.from(item: ItemModel(name: "Milch"), ownerPublicId: "")
        XCTAssertTrue(PriceHistoryViewModel.withFallback([], entry: entry, store: "Edeka").isEmpty)
    }

    func test_history_withPoints_isUnchanged() {
        let entry = ItemCatalogEntry.from(item: ItemModel(name: "Milch", price: 1.49), ownerPublicId: "")
        let point = PricePoint(itemName: "Milch", storeName: "Rewe", purchasedAt: Date(), price: 1.29)
        XCTAssertEqual(PriceHistoryViewModel.withFallback([point], entry: entry, store: "Edeka"), [point])
    }

    func test_lineTotal_isUnitPriceTimesQuantity() {
        XCTAssertEqual(PriceDisplaySetting.lineTotal(ItemModel(name: "Milch", units: 2, price: 1.49)), 2.98, accuracy: 0.0001)
        XCTAssertEqual(PriceDisplaySetting.lineTotal(ItemModel(name: "Brot", units: 1, price: 2.99)), 2.99, accuracy: 0.0001)
    }
}
