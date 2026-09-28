/*
 ConsumptionStatisticsTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für „Verbrauch“: Mengen addieren (l/ml/kg/g/Stück), gemischte Einheiten, nicht zugeordnete Zeilen,
   Sortierung, Hero, Texte, Verlauf, Karte im Archiv; Board-Werte aus InsightUsage.

 🔰 Notes for Beginners:
 - Alle Daten in Europe/Berlin (ReceiptTimes.calendar); Kategorien ohne Nachschlagen (Kontext .empty).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ConsumptionStatisticsTests: XCTestCase {
    private let cal = ReceiptTimes.calendar

    private func date(_ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func line(_ item: String?, _ price: String, qty: Int = 1, units: Double? = nil, _ measure: String? = nil) -> ReceiptLine {
        var l = ReceiptLine(raw: "X", itemName: item, price: Decimal(string: price)!, unitPrice: 0, quantity: qty,
                            isSaved: item != nil)
        l.units = units
        l.measure = measure
        return l
    }

    private func receipt(_ month: Int, _ lines: [ReceiptLine]) -> ArchivedReceipt {
        let total = lines.reduce(Decimal(0)) { $0 + $1.price }
        return ArchivedReceipt(id: UUID(), listId: UUID(), storeName: "Edeka", purchasedAt: date(month, 10), total: total,
                               lineCount: lines.count, savedPriceCount: 0, photoPaths: [], bytes: 0,
                               createdAt: date(month, 10), lines: lines)
    }

    private func usage(_ receipts: [ArchivedReceipt], month: Int = 9) -> UsageInsights {
        ConsumptionStatistics.usage(receipts, month: date(month, 1), context: .empty)
    }

    func test_amounts_addAcrossUnits() {
        let u = usage([receipt(9, [line("Hack", "4.49", units: 500, "g"), line("Hack", "8.99", units: 1, "kg"),
                                   line("Milch", "2.38", qty: 2, units: 1, "l"), line("Milch", "0.99", units: 500, "ml"),
                                   line("Eier", "1.79", units: 6, "piece"), line("Eier", "1.79", units: 10, "piece")])])
        let byName = Dictionary(uniqueKeysWithValues: u.products.map { ($0.name, $0) })
        XCTAssertEqual(byName["Hack"]?.amount, UsageAmount(kind: .mass, value: 1500))
        XCTAssertEqual(byName["Milch"]?.amount, UsageAmount(kind: .volume, value: 2500))
        XCTAssertEqual(byName["Eier"]?.amount, UsageAmount(kind: .unit("piece"), value: 16))
        XCTAssertEqual(UsageInsightsText.amount(byName["Hack"]!.amount), "1,5 kg")
        XCTAssertEqual(UsageInsightsText.amount(byName["Milch"]!.amount), "2,5 l")
        XCTAssertEqual(UsageInsightsText.amount(byName["Eier"]!.amount), "16 Stück")
        XCTAssertEqual(UsageInsightsText.amount(UsageAmount(kind: .mass, value: 250)), "250 g")
    }

    /// Einheiten, die nicht zusammenpassen, oder fehlender Inhalt → Stückzahl laut Bon.
    func test_mixedOrUnknownUnits_countPieces() {
        let u = usage([receipt(9, [line("Käse", "3.00", units: 200, "g"), line("Käse", "2.00", qty: 2, units: 1, "pack"),
                                   line("Brot", "2.00", qty: 3)])])
        let byName = Dictionary(uniqueKeysWithValues: u.products.map { ($0.name, $0) })
        XCTAssertEqual(byName["Käse"]?.amount, UsageAmount(kind: .pieces, value: 3))
        XCTAssertEqual(byName["Brot"]?.amount, UsageAmount(kind: .pieces, value: 3))
    }

    func test_unassignedLines_doNotCount() {
        let u = usage([receipt(9, [line(nil, "0.20"), line("Milch", "1.19", units: 1, "l")])])
        XCTAssertEqual(u.products.map(\.name), ["Milch"])
    }

    /// Sortierung: Anzahl Käufe, dann Kosten; Hero: größte Stückzahl.
    func test_sortingAndHero() {
        let u = usage([receipt(9, [line("A", "1.00"), line("B", "9.00"), line("C", "5.00")]),
                       receipt(9, [line("A", "1.00"), line("C", "5.00", qty: 4)])])
        XCTAssertEqual(u.products.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(u.hero?.name, "C")
        XCTAssertEqual(u.products.first?.purchases, 2)
        XCTAssertEqual(u.products.first?.pieces, 5)
    }

    func test_deltaAndHistory() {
        let u = usage([receipt(8, [line("Milch", "2.38", qty: 2, units: 1, "l")]),
                       receipt(9, [line("Milch", "2.38", qty: 2, units: 1, "l"), line("Milch", "1.19", units: 1, "l")]),
                       receipt(9, [line("Brot", "2.00", qty: 2)]), receipt(8, [line("Brot", "2.00", qty: 3)])])
        let milk = u.products.first { $0.name == "Milch" }!
        XCTAssertEqual(UsageInsightsText.delta(milk), "+1 l")
        XCTAssertEqual(UsageInsightsText.direction(milk), 1)
        XCTAssertEqual(milk.history, [0, 0, 0, 0, 2000, 3000])
        let bread = u.products.first { $0.name == "Brot" }!
        XCTAssertEqual(UsageInsightsText.delta(bread), "\u{2212}1")
        XCTAssertEqual(UsageSparkline.points([2, 2, 1, 2, 2, 2]).map(\.y), [4, 4, 24, 4, 4, 4])
        XCTAssertEqual(UsageSparkline.points([3, 3]).map(\.y), [14, 14], "alle gleich → Mitte")
    }

    /// Board InsightUsage (September 2026).
    func test_insightSamples_matchBoard() {
        let u = ConsumptionStatistics.usage(ArchivedReceipt.insightSamples, month: date(9, 1), context: .designSample)
        XCTAssertEqual(Array(u.products.prefix(7).map(\.name)),
                       ["Milch", "Eier", "Bananen", "Brot", "Hackfleisch", "Kaffee", "Butter"])
        let top = Array(u.products.prefix(7))
        XCTAssertEqual(top.map { UsageInsightsText.amount($0.amount) },
                       ["14 l", "30 Stück", "4,2 kg", "6 Stück", "2 kg", "2 kg", "1,25 kg"])
        XCTAssertEqual(top.map { UsageInsightsText.delta($0) },
                       ["+2 l", "+2", "+0,4 kg", "\u{2212}1", "\u{2212}0,5 kg", "±0", "+0,25 kg"])
        XCTAssertEqual(top.map { InsightFormat.euro($0.cost) },
                       ["16,66", "8,97", "7,52", "20,70", "17,98", "25,98", "12,45"].map { "\($0)\u{00A0}€" })
        XCTAssertEqual(UsageInsightsText.heroTitle(u), "Milch im September")
        XCTAssertEqual(UsageInsightsText.heroValue(u), "14 Liter")
        XCTAssertEqual(UsageInsightsText.chips(u), ["3,3 l pro Woche", "↑ 2 l ggü. August", "16,66\u{00A0}€"])
    }

    func test_emptyMonth_heroTexts() {
        let u = usage([], month: 9)
        XCTAssertTrue(u.isEmpty)
        XCTAssertEqual(UsageInsightsText.heroValue(u), "0,00\u{00A0}€")
        XCTAssertEqual(UsageInsightsText.chips(u), ["Keine Einkäufe"])
    }

    /// Karte im Archiv: aktueller Monat, sonst letzter Monat mit Bons; ohne Bons keine Karte.
    func test_archiveCardSummary() {
        let receipts = [receipt(8, [line("A", "10.00")]), receipt(8, [line("B", "5.50")])]
        let summary = InsightsCardSummary.make(receipts, now: date(9, 20))
        XCTAssertEqual(summary?.title, "Auswertung August")
        XCTAssertEqual(summary?.value, "15,50\u{00A0}€ · 2 Einkäufe")
        XCTAssertNil(InsightsCardSummary.make([], now: date(9, 20)))
    }
}
