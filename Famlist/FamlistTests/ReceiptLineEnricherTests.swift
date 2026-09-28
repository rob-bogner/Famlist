/*
 ReceiptLineEnricherTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für ReceiptLineEnricher: Kategorie, Einheit, Inhalt je Stück und Artikel-ID je Bon-Zeile.

 🔰 Notes for Beginners:
 - Inhalt je Stück = Listenmenge ÷ Stückzahl auf dem Bon (Entscheidung Robert 29.09.2026).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptLineEnricherTests: XCTestCase {
    private let categories = CategoryDefinition.defaults

    private func line(_ item: String?, quantity: Int = 1) -> ReceiptLine {
        ReceiptLine(raw: "BON", itemName: item, price: 1, unitPrice: 1, quantity: quantity, isSaved: item != nil)
    }

    private func catalogEntry(_ name: String, category: String?, measure: String) -> ItemCatalogEntry {
        ItemCatalogEntry(id: "cat-\(name)", ownerPublicId: "owner", name: name, brand: nil, category: category,
                         productDescription: nil, measure: measure, price: 0, imageData: nil)
    }

    func test_listItem_givesCategoryMeasureAndUnitsPerPiece() {
        let enricher = ReceiptLineEnricher(
            listItems: [ItemModel(id: "s1", name: "Schokolade", units: 200, measure: "g", category: "Sonstiges")],
            catalog: [], categories: categories)
        let result = enricher.enrich(line("schokolade", quantity: 2))
        XCTAssertEqual(result.units, 100, "200 g auf der Liste, 2 × auf dem Bon → 100 g je Stück")
        XCTAssertEqual(result.measure, "g")
        XCTAssertEqual(result.category, "Sonstiges")
        XCTAssertEqual(result.itemId, "s1")
    }

    func test_listItem_winsOverCatalog() {
        let enricher = ReceiptLineEnricher(
            listItems: [ItemModel(id: "l1", name: "Milch", units: 2, measure: "l", category: "Milchprodukte")],
            catalog: [catalogEntry("Milch", category: "Getränke", measure: "ml")], categories: categories)
        let result = enricher.enrich(line("Milch", quantity: 2))
        XCTAssertEqual(result.itemId, "l1")
        XCTAssertEqual(result.category, "Milchprodukte")
        XCTAssertEqual(result.units, 1)
        XCTAssertEqual(result.measure, "l")
    }

    /// Der Artikelstamm kennt keine Menge → kein Inhalt je Stück.
    func test_catalogOnly_hasNoUnits() {
        let enricher = ReceiptLineEnricher(listItems: [], catalog: [catalogEntry("Kaffee", category: "Getränke", measure: "kg")],
                                           categories: categories)
        let result = enricher.enrich(line("Kaffee"))
        XCTAssertNil(result.units)
        XCTAssertEqual(result.measure, "kg")
        XCTAssertEqual(result.category, "Getränke")
    }

    func test_unknownOrMissingCategory_fallsBackToSonstiges() {
        let enricher = ReceiptLineEnricher(
            listItems: [ItemModel(id: "x", name: "Batterien", measure: "Stück", category: "Gibt es nicht"),
                        ItemModel(id: "y", name: "Kerzen", measure: "Stück", category: nil)],
            catalog: [], categories: categories)
        XCTAssertEqual(enricher.enrich(line("Batterien")).category, CategoryDefinition.fallbackName)
        XCTAssertEqual(enricher.enrich(line("Kerzen")).category, CategoryDefinition.fallbackName)
    }

    func test_unmatchedLine_staysUnchanged() {
        let enricher = ReceiptLineEnricher(listItems: [ItemModel(id: "a", name: "Butter")], catalog: [], categories: categories)
        XCTAssertEqual(enricher.enrich(line(nil)), line(nil))
        XCTAssertEqual(enricher.enrich(line("Unbekannt")), line("Unbekannt"))
    }

    /// Gespeicherte Werte eines Bons werden beim Anzeigen nicht durch den heutigen Artikel ersetzt.
    func test_existingValues_areKept() {
        var stored = line("Butter")
        stored.category = "Milchprodukte"
        stored.units = 250
        stored.measure = "g"
        stored.itemId = "alt"
        let enricher = ReceiptLineEnricher(
            listItems: [ItemModel(id: "neu", name: "Butter", units: 500, measure: "kg", category: "Sonstiges")],
            catalog: [], categories: categories)
        XCTAssertEqual(enricher.enrich(stored), stored)
    }

    /// Bons von älteren App-Versionen: JSON ohne die neuen Felder bleibt lesbar.
    func test_oldLineJSON_decodes() throws {
        let json = #"{"raw":"KERRYGOLD BUTTER","item":"Butter","price":2.49,"unit_price":2.49,"quantity":1,"saved":true}"#
        let decoded = try JSONDecoder().decode(ReceiptLine.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.itemName, "Butter")
        XCTAssertNil(decoded.category)
        XCTAssertNil(decoded.units)
    }

    func test_newFields_useSnakeCaseKeys() throws {
        var value = line("Butter")
        value.itemId = "b1"
        value.units = 250
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(value), encoding: .utf8))
        XCTAssertTrue(json.contains(#""item_id":"b1""#))
        XCTAssertTrue(json.contains(#""units":250"#))
    }
}
