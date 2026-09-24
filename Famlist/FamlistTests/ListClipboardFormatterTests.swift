/*
 ListClipboardFormatterTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für das Textformat „In Zwischenablage kopieren“ (SPEC §3.4):
   erste Zeile Listenname, dann „• Name · Menge Einheit“ je Artikel.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ListClipboardFormatterTests: XCTestCase {

    func test_designExample_butterPack() {
        let butter = ItemModel(name: "Butter", units: 1, measure: "pack")
        XCTAssertEqual(ListClipboardFormatter.text(listTitle: "My List", items: [butter], scope: .open),
                       "My List\n• Butter · \(butter.quantityText)")
        XCTAssertTrue(butter.quantityText.hasPrefix("1 "))
    }

    func test_openScope_skipsCheckedItems() {
        let items = [ItemModel(name: "Milch", units: 2, measure: "l"),
                     ItemModel(name: "Brot", isChecked: true)]
        let text = ListClipboardFormatter.text(listTitle: "Edeka", items: items, scope: .open)
        XCTAssertEqual(text.components(separatedBy: "\n").count, 2)
        XCTAssertFalse(text.contains("Brot"))
    }

    func test_allScope_includesCheckedItems_inGivenOrder() {
        let items = [ItemModel(name: "Milch", units: 2, measure: "l"),
                     ItemModel(name: "Brot", isChecked: true)]
        let lines = ListClipboardFormatter.text(listTitle: "Edeka", items: items, scope: .all)
            .components(separatedBy: "\n")
        XCTAssertEqual(lines.first, "Edeka")
        XCTAssertTrue(lines[1].hasPrefix("• Milch · 2 "))
        XCTAssertEqual(lines[2], "• Brot")
    }

    func test_withoutMeasure_andMoreThanOne_showsCount() {
        XCTAssertEqual(ListClipboardFormatter.line(for: ItemModel(name: "Eier", units: 6)), "• Eier · 6")
    }

    func test_emptyList_onlyTitle() {
        XCTAssertEqual(ListClipboardFormatter.text(listTitle: "Leer", items: [], scope: .all), "Leer")
    }
}
