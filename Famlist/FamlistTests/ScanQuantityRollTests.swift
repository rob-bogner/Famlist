/*
 ScanQuantityRollTests.swift
 FamlistTests
 Created on: 14.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Barcode-Scanner: Menge direkt setzen (Ausrollen am Mengen-Kreis) und Details der Karte „Artikel erkannt“.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ScanQuantityRollTests: XCTestCase {
    @MainActor
    func testSetQuantityClampsToOneToNine() {
        let vm = BarcodeScanViewModel(catalog: nil, global: nil)
        vm.setQuantity(4)
        XCTAssertEqual(vm.quantity, 4)
        vm.setQuantity(12)
        XCTAssertEqual(vm.quantity, 9)
        vm.setQuantity(0)
        XCTAssertEqual(vm.quantity, 1)
    }

    func testRollValuesStartAtTwo() {
        XCTAssertEqual(ScanQuantityRoll.values, [2, 3, 4, 5, 6])
    }

    func testDetailChipsKeepFreeTextMeasureAndSkipEmpty() {
        let product = ScannedProduct(
            barcode: "1",
            entry: ItemCatalogEntry(id: "x", ownerPublicId: "", name: "Butter", brand: "  ", category: nil,
                                    productDescription: " ", measure: "250 g", price: 0, imageData: nil),
            meta: "")
        XCTAssertEqual(product.detailChips(), ["250 g"])
        XCTAssertNil(product.brand)
        XCTAssertNil(product.details)
    }

    func testRemoteImageOnlyWithoutOwnPhotoAndHttps() {
        var entry = ItemCatalogEntry(id: "x", ownerPublicId: "", name: "Butter", brand: "Kerrygold", category: nil,
                                     productDescription: nil, measure: "", price: 0, imageData: nil)
        entry.imageUrl = "https://images.openfoodfacts.org/a.jpg"
        XCTAssertNotNil(ScannedProduct(barcode: "1", entry: entry, meta: "").remoteImageURL)
        entry.imageUrl = "http://images.openfoodfacts.org/a.jpg"
        XCTAssertNil(ScannedProduct(barcode: "1", entry: entry, meta: "").remoteImageURL)
        entry.imageUrl = "https://images.openfoodfacts.org/a.jpg"
        entry.imageData = "abc"
        XCTAssertNil(ScannedProduct(barcode: "1", entry: entry, meta: "").remoteImageURL)
    }
}
