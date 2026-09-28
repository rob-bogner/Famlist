/*
 ReceiptInsightsViewModelTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für die Auswertung: Monatswechsel mit Grenzen, Startmonat, Texte von Hero und Chips.

 🔰 Notes for Beginners:
 - Beispieldaten ArchivedReceipt.insightSamples (April–September 2026), „heute“ = 28.09.2026.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptInsightsViewModelTests: XCTestCase {
    private let cal = ReceiptTimes.calendar
    private lazy var today = cal.date(from: DateComponents(year: 2026, month: 9, day: 28))!

    private func makeSUT(month: Date? = nil) -> ReceiptInsightsViewModel {
        ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples, context: .designSample, month: month, now: today)
    }

    func test_startsInCurrentMonth_forwardLocked() {
        let sut = makeSUT()
        XCTAssertEqual(sut.monthTitle, "September 2026")
        XCTAssertFalse(sut.canGoForward)
        XCTAssertTrue(sut.canGoBack)
        sut.showNextMonth()
        XCTAssertEqual(sut.monthTitle, "September 2026", "weiter ist im aktuellen Monat gesperrt")
    }

    func test_backStopsAtFirstReceiptMonth() {
        let sut = makeSUT()
        for _ in 0..<10 { sut.showPreviousMonth() }
        XCTAssertEqual(sut.monthTitle, "April 2026")
        XCTAssertFalse(sut.canGoBack)
        sut.showNextMonth()
        XCTAssertEqual(sut.monthTitle, "Mai 2026")
    }

    /// Rückweg aus dem Preisverlauf: gleicher Monat und Reiter.
    func test_givenMonthAndTab_areKept() {
        let august = cal.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let sut = ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples, context: .designSample, tab: .usage,
                                           month: august, now: today)
        XCTAssertEqual(sut.monthTitle, "August 2026")
        XCTAssertEqual(sut.tab, .usage)
    }

    func test_heroTexts_matchBoard() {
        let spend = makeSUT().spend
        XCTAssertEqual(SpendInsightsText.heroTitle(spend), "Ausgegeben im September")
        XCTAssertEqual(SpendInsightsText.heroValue(spend), "412,37\u{00A0}€")
        XCTAssertEqual(SpendInsightsText.chips(spend), ["↑ 8 % ggü. August", "9 Einkäufe", "Ø 45,82\u{00A0}€"])
        XCTAssertEqual(SpendInsightsText.barAverage(spend), "Ø 385 €")
        XCTAssertEqual(spend.stores.map(SpendInsightsText.storeDetail),
                       ["4 × · Ø 39,55\u{00A0}€", "2 × · Ø 65,73\u{00A0}€", "2 × · Ø 44,09\u{00A0}€", "1 × · Ø 34,55\u{00A0}€"])
    }

    /// Monat ohne Bons (Auftrag §6): „0,00 €“, Chip „Keine Einkäufe“.
    func test_emptyMonth_texts() {
        let march = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: march, context: .designSample)
        XCTAssertEqual(SpendInsightsText.heroValue(spend), "0,00\u{00A0}€")
        XCTAssertEqual(SpendInsightsText.chips(spend), ["Keine Einkäufe"])
    }

    func test_changeArrows() {
        XCTAssertEqual(SpendInsightsText.arrow(8), "↑")
        XCTAssertEqual(SpendInsightsText.arrow(-3), "↓")
        XCTAssertEqual(SpendInsightsText.arrow(0), "±")
    }
}
