/*
 ReceiptDetailFormatTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für das Bon-Detail: Kacheln der Einkaufsdaten, Artikelzeilen, Kategoriefarben, Rückweg aus dem
   Preisverlauf.

 🔰 Notes for Beginners:
 - Beispiel = erster Design-Bon (Edeka, 24.09.2026) mit den Werten aus ReceiptDetailMeta.dc.html.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptDetailFormatTests: XCTestCase {
    private let edeka = ArchivedReceipt.designSamples[0]

    private func tile(_ kind: ReceiptMetaTile.Kind, _ receipt: ArchivedReceipt) -> ReceiptMetaTile {
        ReceiptDetailFormat.tiles(receipt, lines: receipt.lines).first { $0.kind == kind }!
    }

    func test_tiles_matchBoard() {
        let tiles = ReceiptDetailFormat.tiles(edeka, lines: edeka.lines)
        XCTAssertEqual(tiles.map(\.value), ["Edeka", "Do, 24.09.", "17:42", "23 min", "5 · 6 Stück", "11,51\u{00A0}€"])
        XCTAssertEqual(tiles.map(\.sub), ["Leopoldstr. 82", "2026", "bis 18:05", "laut Liste", "1 Mehrfachkauf",
                                          "Ø 1,92\u{00A0}€ je Stück"])
        XCTAssertEqual(ReceiptDetailFormat.subtitle(edeka), "Liste Edeka · gescannt von Rob")
    }

    func test_unknownTimes_showDashWithoutSub() {
        var receipt = edeka
        receipt.startedAt = nil
        receipt.endedAt = nil
        XCTAssertEqual(tile(.time, receipt), .unknown(.time))
        XCTAssertEqual(tile(.duration, receipt), .unknown(.duration))
    }

    /// Nur die Uhrzeit laut Bon: Wert = Ende, ohne „bis“; Dauer unbekannt.
    func test_onlyEnd_showsEndWithoutUntil() {
        var receipt = edeka
        receipt.startedAt = nil
        XCTAssertEqual(tile(.time, receipt), ReceiptMetaTile(kind: .time, value: "18:05", sub: nil))
        XCTAssertEqual(tile(.duration, receipt).value, "–")
    }

    /// Bons vor Migration 029: keine Zeilen → Positionen aus dem Zähler, keine Stückzahl.
    func test_receiptWithoutLines() {
        var receipt = edeka
        receipt.lines = nil
        XCTAssertEqual(tile(.items, receipt), ReceiptMetaTile(kind: .items, value: "5 Positionen", sub: nil))
        XCTAssertEqual(tile(.value, receipt), ReceiptMetaTile(kind: .value, value: "11,51\u{00A0}€", sub: nil))
    }

    func test_multiBuyPlural() {
        var receipt = edeka
        receipt.lines = (receipt.lines ?? []).map { line in
            var copy = ReceiptLine(raw: line.raw, itemName: line.itemName, price: line.price, unitPrice: line.unitPrice,
                                   quantity: 2, isSaved: line.isSaved)
            copy.category = line.category
            return copy
        }
        XCTAssertEqual(tile(.items, receipt).sub, "5 Mehrfachkäufe")
        XCTAssertEqual(tile(.items, receipt).value, "5 · 10 Stück")
    }

    func test_rows_textAndColors() {
        let rows = ReceiptDetailFormat.rows(edeka.lines ?? [], context: .designSample)
        XCTAssertEqual(rows.map(\.detail), ["1 × 250 g · je 2,49\u{00A0}€", "1 × 1 l · je 2,29\u{00A0}€", "1 × 400 ml · je 1,39\u{00A0}€",
                                            "1 × 1 l · je 1,85\u{00A0}€", "2 × 100 g · je 1,75\u{00A0}€"])
        XCTAssertEqual(rows.map(\.rank), [1, 3, 4, 3, 5])
        XCTAssertEqual(rows[0].category?.name, "Milchprodukte")
        XCTAssertEqual(rows[4].amount, "3,49\u{00A0}€")
    }

    func test_unassignedLine_isNotTappable_withoutCategory() {
        let line = ReceiptLine(raw: "TUETE", itemName: nil, price: Decimal(string: "0.2")!, unitPrice: Decimal(string: "0.2")!,
                               quantity: 1, isSaved: false)
        let row = ReceiptDetailFormat.rows([line], context: .designSample)[0]
        XCTAssertNil(row.itemName)
        XCTAssertEqual(row.name, "TUETE")
        XCTAssertEqual(row.categoryName, "Ohne Kategorie")
        XCTAssertNil(row.rank)
        XCTAssertEqual(row.detail, "1 Stück · je 0,20\u{00A0}€")
    }

    func test_ranking_byAmount_otherIsGray() {
        func line(_ category: String, _ price: String) -> ReceiptLine {
            var l = ReceiptLine(raw: "X", itemName: "X", price: Decimal(string: price)!, unitPrice: 0, quantity: 1, isSaved: true)
            l.category = category
            return l
        }
        let ranking = CategoryColorRanking.make(lines: [line("Getränke", "3"), line("Backwaren", "5"),
                                                        line("Sonstiges", "99"), line("Getränke", "4"),
                                                        line("Anna", "7"), line("Zoe", "7")])
        // Getränke 3 + 4 = 7, Anna 7, Zoe 7, Backwaren 5: gleicher Betrag → alphabetisch.
        XCTAssertEqual(ranking.rank(of: "Anna"), 0)
        XCTAssertEqual(ranking.rank(of: "Getränke"), 1)
        XCTAssertEqual(ranking.rank(of: "Zoe"), 2)
        XCTAssertEqual(ranking.rank(of: "Backwaren"), 3)
        XCTAssertNil(ranking.rank(of: "Sonstiges"))
        XCTAssertNil(ranking.rank(of: nil))
        XCTAssertEqual(InsightPalette.hex(rank: 6, dark: false), "#3FA66B", "ab Rang 6 beginnt die Palette neu")
        XCTAssertEqual(InsightPalette.hex(rank: nil, dark: true), "#6F8588")
    }

    /// Zurück aus dem Preisverlauf führt dorthin, wo man herkam; darunter liegt dieses Sheet.
    func test_receiptPriceHistory_backAndBase() {
        let back = ActiveListSheet.receiptDetail(edeka, fromMenu: true)
        let entry = ItemCatalogEntry(id: "e", ownerPublicId: "", name: "Butter", brand: nil, category: nil,
                                     productDescription: nil, measure: "", price: 0, imageData: nil)
        let sheet = ActiveListSheet.receiptPriceHistory(entry, back: back)
        XCTAssertEqual(sheet.baseSheet, back)
        XCTAssertEqual(back.baseSheet, .receiptArchive(fromMenu: true))
    }
}
