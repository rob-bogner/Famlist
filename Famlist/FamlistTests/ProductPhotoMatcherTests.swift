/*
 ProductPhotoMatcherTests.swift
 FamlistTests
 Created on: 01.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Per Foto hinzufügen“: strenger Katalog-Abgleich (ProductPhotoMatcher).
   Fall aus dem Test auf dem iPhone: „REWE Bio Süßrahm Butter“ wurde zu „Rewe Bio Erdnussbutter Creamy“.

 📝 Last Change:
 - Initial creation (01.10.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import CoreGraphics
@testable import Famlist

final class ProductPhotoMatcherTests: XCTestCase {
    private func line(_ text: String, _ height: CGFloat) -> ProductPhotoReading.Line {
        .init(text: text, box: CGRect(x: 0.1, y: 0.1, width: 0.5, height: height))
    }

    private func product(_ id: String, _ name: String, _ brand: String?, _ measure: String = "250 g", scans: Int = 100) -> GlobalProductEntry {
        GlobalProductEntry(id: id, name: name, brand: brand, category: nil, measure: measure, imageUrl: nil, scansN: scans)
    }

    private var butterReading: ProductPhotoReading {
        ProductPhotoReading(barcode: nil, lines: [
            line("REWE Bio", 0.05), line("Süßrahm", 0.06), line("BUTTER", 0.09), line("Sahnig milder Geschmack", 0.025),
            line("aus Bio-Milch von Naturland Höfen.", 0.018), line("Haltungs-form", 0.02), line("NUTRI-SCORE", 0.008),
        ])
    }
    private let butterFields = ProductPhotoFields(name: "Butter", brand: "Süßrahm", variant: nil, units: nil, measure: nil)

    func testButterIsNotPeanutButter() {
        let keywords = ProductPhotoMatcher.keywords(reading: butterReading, fields: butterFields)
        let erdnuss = product("1", "Rewe Bio Erdnussbutter Creamy", "Rewe Bio", scans: 500)
        let marke = product("4", "Deutsche Markenbutter", "Rewe Beste Wahl", scans: 900)
        XCTAssertEqual(ProductPhotoMatcher.decide(ProductPhotoMatcher.rank([erdnuss, marke], keywords: keywords, fields: butterFields)), .none)
    }

    func testCompoundWordAndDuplicatesAreCertain() {
        let keywords = ProductPhotoMatcher.keywords(reading: butterReading, fields: butterFields)
        let products = [
            product("1", "Rewe Bio Erdnussbutter Creamy", "Rewe Bio", scans: 500),
            product("2", "Süßrahmbutter", "REWE Bio", scans: 300),
            product("3", "Bio Süßrahm Butter", "Rewe", scans: 100),
            product("7", "Süßrahmbutter mild gesalzen", "Kerrygold", scans: 900),
        ]
        let refined = ProductPhotoMatcher.refine(butterFields, products: products, keywords: keywords)
        XCTAssertEqual(refined?.name, "Süßrahm Butter")
        guard case .certain(let best) = ProductPhotoMatcher.decide(ProductPhotoMatcher.rank(products, keywords: keywords, fields: refined)) else {
            return XCTFail("Süßrahmbutter sollte sicher sein")
        }
        XCTAssertEqual(best.product.id, "2")
    }

    func testForeignBrandIsNotOffered() {
        let reading = ProductPhotoReading(barcode: nil, lines: [
            line("HOFGUT", 0.03), line("Sonnental", 0.03), line("HAFER", 0.09), line("DRINK", 0.09), line("BARISTA", 0.04), line("1 L", 0.03),
        ])
        let fields = ProductPhotoFields(name: "Hafer Drink", brand: "Hofgut Sonnental", variant: "Barista", units: 1, measure: "l")
        let keywords = ProductPhotoMatcher.keywords(reading: reading, fields: fields)
        let products = [product("a", "Hafer Drink Barista", "Oatly", "1 l", scans: 900), product("b", "Haferdrink", "Alpro", "1 l", scans: 500)]
        XCTAssertEqual(ProductPhotoMatcher.decide(ProductPhotoMatcher.rank(products, keywords: keywords, fields: fields)), .none)
    }

    func testSegmentation() {
        XCTAssertEqual(ProductPhotoMatcher.segment("sussrahmbutter", vocabulary: ["sussrahm", "butter"]), ["sussrahm", "butter"])
        XCTAssertNil(ProductPhotoMatcher.segment("erdnussbutter", vocabulary: ["butter", "rewe"]))
    }
}
