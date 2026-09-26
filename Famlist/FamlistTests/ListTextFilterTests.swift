/*
 ListTextFilterTests.swift
 FamlistTests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den Listenfilter (Suchleiste oben): Groß/klein, Akzente, Marke, abgehakte Artikel, Reihenfolge.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ListTextFilterTests: XCTestCase {
    private let items = [
        ItemModel(id: "1", name: "Milch", units: 2, measure: "l"),
        ItemModel(id: "2", name: "Äpfel", units: 1, measure: "kg"),
        ItemModel(id: "3", name: "Buttermilch", units: 1, isChecked: true),
        ItemModel(id: "4", name: "Joghurt", units: 1, brand: "Weihenstephan")
    ]

    func test_emptyQuery_matchesEverything() {
        XCTAssertEqual(ListTextFilter.filter(items, query: "  ").count, 4)
    }

    func test_caseInsensitive_includesChecked_keepsOrder() {
        XCTAssertEqual(ListTextFilter.filter(items, query: "MILCH").map(\.id), ["1", "3"])
    }

    func test_diacriticInsensitive() {
        XCTAssertEqual(ListTextFilter.filter(items, query: "apfel").map(\.id), ["2"])
    }

    func test_matchesBrand() {
        XCTAssertEqual(ListTextFilter.filter(items, query: "weihen").map(\.id), ["4"])
    }
}
