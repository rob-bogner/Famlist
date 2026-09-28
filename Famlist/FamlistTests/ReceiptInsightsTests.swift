/*
 ReceiptInsightsTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für ReceiptInsights („Ausgaben“): Monatssumme trotz Rabatt/Pfand, Monatsgrenzen und Zeitzone,
   Monate ohne Bons, Top-6-Regel, Läden, Startmonat.

 🔰 Notes for Beginners:
 - Alle Daten in Europe/Berlin (ReceiptTimes.calendar), Kategorien ohne Nachschlagen (Kontext .empty).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptInsightsTests: XCTestCase {
    private let cal = ReceiptTimes.calendar

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func d(_ s: String) -> Decimal { Decimal(string: s)! }

    private func line(_ category: String?, _ price: String) -> ReceiptLine {
        var l = ReceiptLine(raw: "X", itemName: category == nil ? nil : "A", price: d(price), unitPrice: d(price),
                            quantity: 1, isSaved: category != nil)
        l.category = category
        return l
    }

    private func receipt(_ store: String, _ day: Date, _ total: String, lines: [ReceiptLine]? = nil) -> ArchivedReceipt {
        ArchivedReceipt(id: UUID(), listId: UUID(), storeName: store, purchasedAt: day, total: d(total), lineCount: 0,
                        savedPriceCount: 0, photoPaths: [], bytes: 0, createdAt: day, lines: lines)
    }

    /// Rabatt und Pfand stecken in der Differenz → „Sonstiges“; Σ Kategorien = Monatssumme.
    func test_categories_sumEqualsMonthTotal_withDiscountAndDeposit() {
        let receipts = [
            receipt("Edeka", date(9, 3), "10.00", lines: [line("Obst & Gemüse", "6.00"), line("Getränke", "3.25")]),
            receipt("Rewe", date(9, 5), "4.50", lines: [line("Getränke", "5.00")]),          // Rabatt −0,50
            receipt("Lidl", date(9, 7), "5.00")                                             // ohne Zeilen
        ]
        let spend = ReceiptInsights.spend(receipts, month: date(9, 1), context: .empty)
        XCTAssertEqual(spend.total, d("19.50"))
        XCTAssertEqual(spend.categories.reduce(Decimal(0)) { $0 + $1.amount }, spend.total)
        XCTAssertEqual(spend.categories.map(\.name), ["Getränke", "Obst & Gemüse", "Sonstiges"])
        XCTAssertEqual(spend.categories.last?.amount, d("5.25"), "0,75 Pfand + (−0,50) Rabatt + 5,00 ohne Zeilen")
        XCTAssertEqual(spend.count, 3)
        XCTAssertEqual(spend.average, d("6.5"))
    }

    /// 31.08. 23:59 gehört zum August, 01.09. 00:00 zum September – nach Berliner Zeit.
    func test_monthBoundaries_useBerlinTime() {
        let receipts = [receipt("A", date(8, 31, 23, 59), "1.00"), receipt("B", date(9, 1, 0, 0), "2.00")]
        XCTAssertEqual(ReceiptInsights.spend(receipts, month: date(8, 15), context: .empty).total, d("1.00"))
        XCTAssertEqual(ReceiptInsights.spend(receipts, month: date(9, 15), context: .empty).total, d("2.00"))
        let utc = Calendar(identifier: .gregorian)
        XCTAssertEqual(utc.dateComponents(in: TimeZone(identifier: "UTC")!, from: date(9, 1, 0, 0)).month, 8,
                       "In UTC wäre es noch August – gezählt wird trotzdem September")
    }

    /// Monate ohne Bons: Säule 0, nicht im Schnitt; ohne Vormonat keine Veränderung.
    func test_monthsWithoutReceipts() {
        let receipts = [receipt("A", date(6, 10), "300"), receipt("B", date(9, 10), "400")]
        let spend = ReceiptInsights.spend(receipts, month: date(9, 1), context: .empty)
        XCTAssertEqual(spend.bars.map(\.total), [0, 0, 300, 0, 0, 400].map { Decimal($0) })
        XCTAssertEqual(spend.bars.map(\.isSelected), [false, false, false, false, false, true])
        XCTAssertEqual(spend.barAverage, 350)
        XCTAssertNil(spend.changePercent, "August hat keine Bons")

        let empty = ReceiptInsights.spend(receipts, month: date(8, 1), context: .empty)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.total, 0)
        XCTAssertNil(empty.average)
        XCTAssertTrue(empty.categories.isEmpty)
        XCTAssertTrue(empty.stores.isEmpty)
    }

    func test_changePercent_againstPreviousMonth() {
        let receipts = [receipt("A", date(8, 10), "382"), receipt("B", date(9, 10), "412.37")]
        XCTAssertEqual(ReceiptInsights.spend(receipts, month: date(9, 1), context: .empty).changePercent, 8)
        XCTAssertEqual(ReceiptInsights.change(from: 400, to: 300), -25)
    }

    /// Höchstens 6 Kategorien; die kleineren kommen zu „Sonstiges“.
    func test_top6_restGoesToOther() {
        let names = ["A", "B", "C", "D", "E", "F", "G", "H"]
        let lines = names.enumerated().map { index, name in line(name, "\(10 - index)") }   // 10, 9, … 3
        let receipts = [receipt("Edeka", date(9, 3), "52", lines: lines)]
        let spend = ReceiptInsights.spend(receipts, month: date(9, 1), context: .empty)
        XCTAssertEqual(spend.categories.map(\.name), ["A", "B", "C", "D", "E", "F", "Sonstiges"])
        XCTAssertEqual(spend.categories.last?.amount, 7, "G 4 + H 3")
        XCTAssertEqual(spend.categories.last?.isOther, true)
        XCTAssertEqual(spend.categories.first?.percent, 19)
    }

    func test_stores_groupedAndRelativeToLargest() {
        let receipts = [receipt("Edeka", date(9, 2), "40"), receipt("EDEKA", date(9, 9), "60"),
                        receipt("dm", date(9, 4), "25")]
        let stores = ReceiptInsights.spend(receipts, month: date(9, 1), context: .empty).stores
        XCTAssertEqual(stores.map(\.name), ["Edeka", "dm"])
        XCTAssertEqual(stores.map(\.count), [2, 1])
        XCTAssertEqual(stores.map(\.average), [50, 25])
        XCTAssertEqual(stores.map(\.fraction), [1, 0.25])
    }

    func test_defaultMonth_currentOrLastWithReceipts() {
        let receipts = [receipt("A", date(7, 10), "1"), receipt("B", date(8, 10), "1")]
        XCTAssertEqual(ReceiptInsights.defaultMonth(receipts, now: date(9, 20)), date(8, 1, 0, 0))
        XCTAssertEqual(ReceiptInsights.defaultMonth(receipts + [receipt("C", date(9, 2), "1")], now: date(9, 20)),
                       date(9, 1, 0, 0))
        XCTAssertNil(ReceiptInsights.defaultMonth([], now: date(9, 20)))
        XCTAssertEqual(ReceiptInsights.firstMonth(receipts), date(7, 1, 0, 0))
    }

    /// Die Beispieldaten entsprechen dem Board InsightSpend.
    func test_insightSamples_matchBoard() {
        let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: date(9, 1), context: .designSample)
        XCTAssertEqual(spend.total, d("412.37"))
        XCTAssertEqual(spend.count, 9)
        XCTAssertEqual(spend.average, d("45.82"))
        XCTAssertEqual(spend.changePercent, 8)
        XCTAssertEqual(spend.bars.map { InsightFormat.wholeEuro($0.total) },
                       ["356 €", "389 €", "372 €", "401 €", "382 €", "412 €"])
        XCTAssertEqual(spend.barAverage.map(InsightFormat.wholeEuro), "385 €")
        XCTAssertEqual(spend.categories.map(\.name), ["Obst & Gemüse", "Milchprodukte", "Fleisch & Wurst", "Getränke",
                                                      "Backwaren", "Süßes & Snacks", "Sonstiges"])
        XCTAssertEqual(spend.categories.map(\.amount),
                       ["96.40", "71.20", "64.90", "45.30", "38.10", "29.80", "66.67"].map { d($0) })
        XCTAssertEqual(spend.categories.map(\.percent), [23, 17, 16, 11, 9, 7, 16])
        XCTAssertEqual(spend.stores.map(\.name), ["Edeka", "Rewe", "Lidl", "dm"])
        XCTAssertEqual(spend.stores.map(\.total), ["158.20", "131.45", "88.17", "34.55"].map { d($0) })
        XCTAssertEqual(spend.stores.map { Int(($0.fraction * 100).rounded()) }, [100, 83, 56, 22])
    }
}
