/*
 ConsumptionStatistics.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Berechnet die Auswertung „Verbrauch“: Zeilen je Artikel (PricePoint.key des Artikelnamens) im Monat,
   Menge = Σ Stückzahl × Inhalt je Stück in der Einheit, Kosten, Verlauf über 6 Monate, Vormonat.

 🔰 Notes for Beginners:
 - Nicht zugeordnete Zeilen zählen nicht. Einheiten eines Artikels, die nicht zusammenpassen → Stückzahl.
 - Sortierung: Anzahl Käufe, dann Kosten, dann Name.
 - Offline: nur die übergebenen Bons. Reine Funktion → Unit-Tests (ConsumptionStatisticsTests).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum ConsumptionStatistics {
    static func usage(_ all: [ArchivedReceipt], month: Date, context: ReceiptLineContext,
                      calendar: Calendar = ReceiptTimes.calendar) -> UsageInsights {
        let start = ReceiptInsights.monthStart(month, calendar: calendar)
        let months = (0..<ReceiptInsights.barMonths).reversed().map {
            ReceiptInsights.adding(months: -$0, to: start, calendar: calendar)
        }
        let byMonth = months.map { grouped(ReceiptInsights.receipts(all, in: $0, calendar: calendar), context: context) }
        let current = byMonth.last ?? [:]
        let previous = byMonth.count > 1 ? byMonth[byMonth.count - 2] : [:]
        let products = current.map { key, lines in
            product(key: key, lines: lines, previous: previous[key], history: byMonth.map { $0[key] ?? [] },
                    ranking: context.ranking)
        }
        return UsageInsights(month: start, previousMonth: months.count > 1 ? months[months.count - 2] : start,
                             products: products.sorted(by: order))
    }

    /// Zugeordnete Zeilen je Artikel-Schlüssel.
    private static func grouped(_ receipts: [ArchivedReceipt], context: ReceiptLineContext) -> [String: [ReceiptLine]] {
        let lines = receipts.flatMap { context.lines(of: $0) }.filter { $0.itemName != nil }
        return Dictionary(grouping: lines) { PricePoint.key(for: $0.itemName ?? "") }
    }

    private static func product(key: String, lines: [ReceiptLine], previous: [ReceiptLine]?, history: [[ReceiptLine]],
                                ranking: CategoryColorRanking) -> UsageInsights.Product {
        let amount = UsageAmount.sum(lines)
        let before = previous.map(UsageAmount.sum) ?? UsageAmount(kind: amount.kind, value: 0)
        let category = lines.last?.category
        return UsageInsights.Product(
            key: key, name: lines.last?.itemName ?? key, category: category, rank: ranking.rank(of: category),
            purchases: lines.count, pieces: lines.reduce(0) { $0 + max($1.quantity, 1) },
            cost: lines.reduce(Decimal(0)) { $0 + $1.price }, amount: amount,
            previous: before.kind == amount.kind ? before : nil,
            history: history.map { month in
                let value = UsageAmount.sum(month)
                return month.isEmpty || value.kind == amount.kind ? value.value : Double(month.count)
            })
    }

    private static func order(_ a: UsageInsights.Product, _ b: UsageInsights.Product) -> Bool {
        if a.purchases != b.purchases { return a.purchases > b.purchases }
        if a.cost != b.cost { return a.cost > b.cost }
        return a.name < b.name
    }
}
