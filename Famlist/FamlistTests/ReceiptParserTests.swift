/*
 ReceiptParserTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den Bon-Parser mit 4 Beispiel-Bons als Text (REWE, Lidl, dm, EDEKA),
   die unscharfe Zuordnung und die Preis-Statistik (Phase 7).

 🔰 Notes for Beginners:
 - Die Bons sind so aufgebaut, wie Vision die Zeilen liefert: Text und Preis in einer Zeile.

 📝 Last Change:
 - 25.09.2026: Audit-Fixes – Tests für Rabatte mit nachgestelltem/alleinstehendem Minus,
   Summenwörter nur als ganzes Wort, Gewichtszeilen mit Endpreis.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptParserTests: XCTestCase {

    private func d(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    // MARK: - Beispiel-Bons

    func test_rewe_withQuantityLine_andTotal() {
        let bon = """
        REWE Markt GmbH
        Musterstraße 12
        80331 München
        EUR
        KERRYGOLD BUTTER         2,49 B
        ALPRO SOJA DRINK         2,29 B
        BANANEN                  2,58 B
        2 Stk x 1,29
        KOKOSM. 400ML            1,39 B
        --------------------------------
        SUMME                EUR 8,75
        Geg. BAR             EUR 10,00
        Rückgeld BAR         EUR 1,25
        Datum: 24.09.2026 18:42
        """
        let r = ReceiptParser.parse(lines: bon.components(separatedBy: "\n"))
        XCTAssertEqual(r.store, "REWE")
        XCTAssertEqual(r.lines.map(\.raw), ["KERRYGOLD BUTTER", "ALPRO SOJA DRINK", "BANANEN", "KOKOSM. 400ML"])
        XCTAssertEqual(r.lines.map(\.price), [d("2.49"), d("2.29"), d("2.58"), d("1.39")])
        XCTAssertEqual(r.total, d("8.75"))
        let c = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: r.date!)
        XCTAssertEqual([c.day, c.month, c.year], [24, 9, 2026])
    }

    func test_lidl_taxLetters_pfandSkipped_shortYear() {
        let bon = """
        LIDL
        Lidl Dienstleistung GmbH & Co. KG
        Milch Mandel o.Z.         1,85 A
        Mineralwasser 1,5l        0,29 A
        Pfand 0,25                0,25 A
        Bio Vollmilch-Schoko      3,49 A*
        zu zahlen                 5,88
        EC-Karte                  5,88
        MwSt A 7%  5,50  0,38
        03.09.26 17:05
        """
        let r = ReceiptParser.parse(lines: bon.components(separatedBy: "\n"))
        XCTAssertEqual(r.store, "Lidl")
        XCTAssertEqual(r.lines.map(\.raw), ["Milch Mandel o.Z.", "Mineralwasser 1,5l", "Bio Vollmilch-Schoko"])
        XCTAssertEqual(r.total, d("5.88"))
        let c = Calendar(identifier: .gregorian).dateComponents([.year], from: r.date!)
        XCTAssertEqual(c.year, 2026)
    }

    func test_dm_discountSubtractedFromPreviousLine() {
        let bon = """
        dm-drogerie markt
        Balea Duschgel            0,95 1
        Zahnpasta Sensitive       2,45 1
        Rabatt 10%               -0,25 1
        SUMME EUR                 3,15
        """
        let r = ReceiptParser.parse(lines: bon.components(separatedBy: "\n"))
        XCTAssertEqual(r.store, "dm")
        XCTAssertEqual(r.lines.map(\.raw), ["Balea Duschgel", "Zahnpasta Sensitive"])
        XCTAssertEqual(r.lines.last?.price, d("2.20"))
        XCTAssertEqual(r.total, d("3.15"))
        XCTAssertEqual(r.computedTotal, d("3.15"))
    }

    func test_edeka_weightLine_noTotal_usesComputed() {
        let bon = """
        EDEKA Center
        Tomaten Rispe             1,60 A
        0,534 kg x 2,99 EUR/kg
        Brot Dinkel               3,20 A
        Butter Weidemilch         2,19 A
        Payback Punkte            12
        """
        let r = ReceiptParser.parse(lines: bon.components(separatedBy: "\n"))
        XCTAssertEqual(r.store, "EDEKA")
        XCTAssertEqual(r.lines.map(\.raw), ["Tomaten Rispe", "Brot Dinkel", "Butter Weidemilch"])
        XCTAssertNil(r.total)
        XCTAssertEqual(r.computedTotal, d("6.99"))
        XCTAssertNil(r.date)
    }

    func test_emptyAndGarbage_giveNoLines() {
        XCTAssertTrue(ReceiptParser.parse(lines: []).lines.isEmpty)
        XCTAssertTrue(ReceiptParser.parse(lines: ["*** Vielen Dank ***", "12345", "----"]).lines.isEmpty)
    }

    // MARK: - Zuordnung

    func test_matcher_statuses_likeDesign() {
        let items = ["Kerrygold, original irische Butter", "Soyamilch", "Kokosmilch", "Milch Mandel ohne Zucker"]
        XCTAssertEqual(ReceiptItemMatcher.match("KERRYGOLD BUTTER", candidates: items).status, .matched)
        XCTAssertEqual(ReceiptItemMatcher.match("KERRYGOLD BUTTER", candidates: items).candidate,
                       "Kerrygold, original irische Butter")
        XCTAssertEqual(ReceiptItemMatcher.match("KOKOSM. 400ML", candidates: items).candidate, "Kokosmilch")
        XCTAssertEqual(ReceiptItemMatcher.match("FAIRGL.VM SCHOKO", candidates: items).status, .new)
    }

    func test_matcher_ignoresUmlautsAndQuantities() {
        XCTAssertEqual(ReceiptItemMatcher.tokens("Käse 250G"), ["kase"])
        XCTAssertEqual(ReceiptItemMatcher.match("KAESE GOUDA", candidates: ["Käse"]).status, .check)
    }

    // MARK: - Preis-Statistik

    func test_statistics_minAvgMax_months_cheapestStore() {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 24))!
        func date(_ m: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: 10))! }
        let points = [PricePoint(itemName: "Butter", storeName: "Edeka", purchasedAt: date(9), price: d("2.49")),
                      PricePoint(itemName: "Butter", storeName: "Lidl", purchasedAt: date(3), price: d("2.19")),
                      PricePoint(itemName: "Butter", storeName: "Edeka", purchasedAt: date(6), price: d("2.59"))]
        let s = PriceStatistics.make(points: points, now: now, calendar: cal)
        XCTAssertEqual(s.min, d("2.19"))
        XCTAssertEqual(s.max, d("2.59"))
        XCTAssertEqual(s.average, (d("2.49") + d("2.19") + d("2.59")) / 3)
        XCTAssertEqual(s.months.count, 7)
        XCTAssertEqual(s.months.first.map { cal.component(.month, from: $0.start) }, 3)
        XCTAssertEqual(s.months.compactMap(\.average).count, 3)
        XCTAssertEqual(s.stores.map(\.store), ["Edeka", "Lidl"])
        XCTAssertEqual(s.stores.first { $0.isCheapest }?.store, "Lidl")
        XCTAssertEqual(s.latest?.storeName, "Edeka")
    }

    func test_statistics_empty() {
        let s = PriceStatistics.make(points: [])
        XCTAssertNil(s.min)
        XCTAssertTrue(s.stores.isEmpty)
        XCTAssertEqual(s.months.count, 7)
    }
}

extension ReceiptParserTests {
    func test_skipWords_onlyWholeWords() {
        let r = ReceiptParser.parse(lines: ["BARILLA SPAGHETTI   1,49 A", "Geg. BAR   5,00"])
        XCTAssertEqual(r.lines.map(\.raw), ["BARILLA SPAGHETTI"])
    }
}

// MARK: - Audit-Fixes

extension ReceiptParserTests {
    func test_discount_trailingMinus_reducesPreviousLine() {
        let r = ReceiptParser.parse(lines: ["Butter   2,49 A", "Rabatt   0,50-", "Milch   1,00 A"])
        XCTAssertEqual(r.lines.map(\.raw), ["Butter", "Milch"])
        XCTAssertEqual(r.lines.map(\.price), [d("1.99"), d("1.00")])
    }

    func test_discount_trailingMinus_withTaxLetter() {
        let r = ReceiptParser.parse(lines: ["Butter   2,49 A", "Preisvorteil   0,50- A"])
        XCTAssertEqual(r.lines.map(\.price), [d("1.99")])
    }

    func test_discount_standaloneMinusLine() {
        let r = ReceiptParser.parse(lines: ["Butter   2,49 A", "-0,50"])
        XCTAssertEqual(r.lines.map(\.price), [d("1.99")])
    }

    func test_discount_withLabel_leadingMinus() {
        let r = ReceiptParser.parse(lines: ["Butter   2,49 A", "Rabatt -0,50"])
        XCTAssertEqual(r.lines.map(\.price), [d("1.99")])
    }

    func test_discount_neverBelowZero() {
        let r = ReceiptParser.parse(lines: ["Kaugummi   0,30 A", "Rabatt   -0,50"])
        XCTAssertEqual(r.lines.map(\.price), [d("0")])
    }

    func test_totalWords_onlyWholeWords() {
        let r = ReceiptParser.parse(lines: ["SUMMERROLLS   3,99 A", "TOTALSCHADEN SPRAY   1,00 A",
                                            "GESAMTKORN BROT   2,50 A", "SUMME EUR   7,49"])
        XCTAssertEqual(r.lines.map(\.raw), ["SUMMERROLLS", "TOTALSCHADEN SPRAY", "GESAMTKORN BROT"])
        XCTAssertEqual(r.total, d("7.49"))
    }

    func test_totalWords_compoundTotalsStillRecognized() {
        XCTAssertEqual(ReceiptParser.parse(lines: ["Brot   2,50 A", "GESAMTSUMME   2,50"]).total, d("2.50"))
        XCTAssertEqual(ReceiptParser.parse(lines: ["Brot   2,50 A", "Gesamtbetrag EUR 2,50"]).total, d("2.50"))
    }

    func test_weightLine_withEndPrice_assignedToNameLineBefore() {
        let bon = ["EDEKA", "Tomaten Rispe", "0,512 kg x 9,99 EUR/kg   5,11 A", "Brot Dinkel   3,20 A"]
        let r = ReceiptParser.parse(lines: bon)
        XCTAssertEqual(r.lines.map(\.raw), ["Tomaten Rispe", "Brot Dinkel"])
        XCTAssertEqual(r.lines.map(\.price), [d("5.11"), d("3.20")])
    }

    func test_weightLine_withEndPrice_afterPricedLine_noDuplicate() {
        let r = ReceiptParser.parse(lines: ["Tomaten   5,11 A", "0,512 kg x 9,99 EUR/kg   5,11 A"])
        XCTAssertEqual(r.lines.map(\.raw), ["Tomaten"])
        XCTAssertEqual(r.lines.map(\.price), [d("5.11")])
    }
}
