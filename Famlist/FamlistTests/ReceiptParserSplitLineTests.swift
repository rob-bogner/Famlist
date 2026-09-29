/*
 ReceiptParserSplitLineTests.swift
 FamlistTests

 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für zerknitterte Bons: Name und Preis stehen in getrennten OCR-Zeilen.

 🔰 Notes for Beginners:
 - Der erste Bon ist die echte Vision-Ausgabe eines REWE-Bons vom 28.09.2026 (Foto aus der App).
   Vorher wurden daraus die Positionen „EUR“, „EUR“ und „AS-Zeit 28.09.“; richtig ist nur „BONUS EIS“.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptParserSplitLineTests: XCTestCase {

    private func d(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    func test_crumpledRewe_priceAboveName_isOneArticle() {
        let bon = ["Josephsburgstr. 37   REWE", "81673 München", "UID Nr. : DE812706034   EUR", "2,00 B",
                   "BONUS EIS", "2 Stk x   1,00", "EUR   2,00", "SUMME", "EUR   2,00", "Geg. EC-Cash",
                   "** Kundenbeleg**   28.09.2026", "Datum:   16:53:46_Uhr", "Pos-Info   16:53 Uhr",
                   "AS-Zeit 28.09.   2,00", "Betrag EUR", "B=   7,0%   1,87   0,13   2,00"]
        let r = ReceiptParser.parse(lines: bon)
        XCTAssertEqual(r.store, "REWE")
        XCTAssertEqual(r.lines.map(\.raw), ["BONUS EIS"])
        XCTAssertEqual(r.lines.map(\.price), [d("2.00")])
        XCTAssertEqual(r.lines.map(\.quantity), [2])
        XCTAssertEqual(r.total, d("2.00"))
        XCTAssertEqual(r.address, "Josephsburgstr. 37", "„REWE“ aus derselben OCR-Zeile gehört nicht zur Adresse")
    }

    func test_nameLine_thenPriceLine_isOneArticle() {
        let r = ReceiptParser.parse(lines: ["KERRYGOLD BUTTER", "2,49 B", "MILCH   1,19 A", "SUMME   3,68"])
        XCTAssertEqual(r.lines.map(\.raw), ["KERRYGOLD BUTTER", "MILCH"])
        XCTAssertEqual(r.lines.map(\.price), [d("2.49"), d("1.19")])
    }

    func test_priceLine_quantityLine_nameLine_isOneArticleWithQuantity() {
        let r = ReceiptParser.parse(lines: ["2,58 B", "2 Stk x 1,29", "BANANEN", "SUMME   2,58"])
        XCTAssertEqual(r.lines.map(\.raw), ["BANANEN"])
        XCTAssertEqual(r.lines.map(\.quantity), [2])
    }

    func test_eurAlone_isNeverAnArticle() {
        let r = ReceiptParser.parse(lines: ["BROT   2,50 A", "EUR   2,50", "EUR"])
        XCTAssertEqual(r.lines.map(\.raw), ["BROT"])
    }

    func test_totalWithoutAmount_takesAmountFromNextLine() {
        let r = ReceiptParser.parse(lines: ["BROT   2,50 A", "SUMME", "EUR   2,50", "Geg. EC-Cash   EUR   2,50",
                                            "AS-Zeit 28.09.   2,50"])
        XCTAssertEqual(r.total, d("2.50"))
        XCTAssertEqual(r.lines.map(\.raw), ["BROT"], "Nach der Summe folgen keine Positionen mehr")
    }

    func test_bonusIsArticleWord_guthabenIsSkipped() {
        let r = ReceiptParser.parse(lines: ["BONUS EIS   2,00 B", "Bonus-Guthaben eingelöst   1,00", "SUMME   2,00"])
        XCTAssertEqual(r.lines.map(\.raw), ["BONUS EIS"])
    }
}
