/*
 ReceiptInsights.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Berechnet die Auswertung „Ausgaben“ aus den Bons des Archivs (RECEIPT_INSIGHTS_PROMPT.md, „Berechnungen“).

 🔰 Notes for Beginners:
 - Monat eines Bons = Kalendertag von purchased_at in Europe/Berlin (ReceiptTimes.calendar).
 - Kategorien: Beträge der Zeilen je Kategorie; höchstens 6 nach Betrag. Rest, nicht zugeordnete Zeilen und die
   Differenz „Summe laut Bon − Σ Zeilen“ (Pfand, Rabatte) landen in „Sonstiges“ → Σ = Monatssumme.
   Bons ohne gespeicherte Zeilen (vor Migration 029) zählen ganz zu „Sonstiges“.
 - 6-Monats-Säulen: Monate ohne Bons zählen als 0 und nicht zum Schnitt.
 - Offline: rechnet nur mit den übergebenen (lokal vorhandenen) Bons, ausstehende eingeschlossen.
 - Reine Funktionen → Unit-Tests (ReceiptInsightsTests).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptInsights {
    static let maxCategories = 6
    static let barMonths = 6

    // MARK: - Monate

    static func monthStart(_ date: Date, calendar: Calendar = ReceiptTimes.calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func adding(months: Int, to month: Date, calendar: Calendar = ReceiptTimes.calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: monthStart(month, calendar: calendar)) ?? month
    }

    static func receipts(_ receipts: [ArchivedReceipt], in month: Date,
                         calendar: Calendar = ReceiptTimes.calendar) -> [ArchivedReceipt] {
        let start = monthStart(month, calendar: calendar)
        return receipts.filter { monthStart($0.purchasedAt, calendar: calendar) == start }
    }

    /// Aktueller Monat; gibt es darin keinen Bon, der letzte Monat mit Bons. nil ohne Bons.
    static func defaultMonth(_ receipts: [ArchivedReceipt], now: Date = Date(),
                             calendar: Calendar = ReceiptTimes.calendar) -> Date? {
        let current = monthStart(now, calendar: calendar)
        let months = Set(receipts.map { monthStart($0.purchasedAt, calendar: calendar) })
        if months.contains(current) { return current }
        return months.filter { $0 <= current }.max() ?? months.max()
    }

    /// Frühester Monat mit Bons („zurück“ ist davor gesperrt).
    static func firstMonth(_ receipts: [ArchivedReceipt], calendar: Calendar = ReceiptTimes.calendar) -> Date? {
        receipts.map { monthStart($0.purchasedAt, calendar: calendar) }.min()
    }

    // MARK: - Ausgaben

    static func spend(_ all: [ArchivedReceipt], month: Date, context: ReceiptLineContext,
                      calendar: Calendar = ReceiptTimes.calendar) -> SpendInsights {
        let start = monthStart(month, calendar: calendar)
        let inMonth = receipts(all, in: start, calendar: calendar)
        let total = inMonth.reduce(Decimal(0)) { $0 + $1.total }
        let previous = adding(months: -1, to: start, calendar: calendar)
        let previousTotal = receipts(all, in: previous, calendar: calendar).reduce(Decimal(0)) { $0 + $1.total }
        let bars = monthBars(all, selected: start, calendar: calendar)
        let withReceipts = bars.filter(\.hasReceipts)
        return SpendInsights(
            month: start, previousMonth: previous, total: total, count: inMonth.count,
            average: inMonth.isEmpty ? nil : rounded(total / Decimal(inMonth.count)),
            changePercent: change(from: previousTotal, to: total),
            bars: bars,
            barAverage: withReceipts.isEmpty ? nil
                : withReceipts.reduce(Decimal(0)) { $0 + $1.total } / Decimal(withReceipts.count),
            categories: categories(inMonth, total: total, context: context),
            stores: stores(inMonth))
    }

    private static func monthBars(_ all: [ArchivedReceipt], selected: Date, calendar: Calendar) -> [SpendInsights.MonthBar] {
        (0..<barMonths).reversed().map { back in
            let month = adding(months: -back, to: selected, calendar: calendar)
            let inMonth = receipts(all, in: month, calendar: calendar)
            return SpendInsights.MonthBar(month: month, total: inMonth.reduce(Decimal(0)) { $0 + $1.total },
                                          hasReceipts: !inMonth.isEmpty, isSelected: back == 0)
        }
    }

    /// Ganze Prozent; nil ohne Vormonat.
    static func change(from previous: Decimal, to current: Decimal) -> Int? {
        guard previous > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: (current - previous) / previous * 100).doubleValue
        return Int(ratio.rounded())
    }

    // MARK: - Kategorien

    private static func categories(_ receipts: [ArchivedReceipt], total: Decimal,
                                   context: ReceiptLineContext) -> [SpendInsights.CategoryShare] {
        var sums: [String: Decimal] = [:]
        var other = Decimal(0)
        for receipt in receipts {
            let lines = context.lines(of: receipt)
            var assigned = Decimal(0)
            for line in lines {
                assigned += line.price
                if let name = line.category, !CategoryColorRanking.isOther(name) {
                    sums[name, default: 0] += line.price
                } else {
                    other += line.price
                }
            }
            other += receipt.total - assigned            // Pfand, Rabatte; ohne Zeilen der ganze Bon
        }
        let sorted = sums.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        other += sorted.dropFirst(maxCategories).reduce(Decimal(0)) { $0 + $1.value }
        var shares = sorted.prefix(maxCategories).map { name, amount in
            SpendInsights.CategoryShare(name: name, amount: amount, percent: percent(amount, of: total),
                                        rank: context.ranking.rank(of: name), isOther: false)
        }
        if other != 0 {
            shares.append(SpendInsights.CategoryShare(name: CategoryDefinition.fallbackName, amount: other,
                                                      percent: percent(other, of: total), rank: nil, isOther: true))
        }
        return shares
    }

    static func percent(_ part: Decimal, of total: Decimal) -> Int {
        guard total > 0 else { return 0 }
        return Int(NSDecimalNumber(decimal: part / total * 100).doubleValue.rounded())
    }

    // MARK: - Läden

    private static func stores(_ receipts: [ArchivedReceipt]) -> [SpendInsights.StoreShare] {
        let groups = Dictionary(grouping: receipts) { $0.storeName.lowercased() }
        let rows = groups.values.compactMap { group -> (String, Int, Decimal)? in
            guard let first = group.first else { return nil }
            return (first.storeName, group.count, group.reduce(Decimal(0)) { $0 + $1.total })
        }
        let maxTotal = rows.map(\.2).max() ?? 0
        return rows
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map { name, count, total in
                SpendInsights.StoreShare(
                    name: name, count: count, total: total, average: rounded(total / Decimal(count)),
                    fraction: maxTotal > 0 ? NSDecimalNumber(decimal: total / maxTotal).doubleValue : 0)
            }
    }

    static func rounded(_ value: Decimal) -> Decimal { ReceiptDetailFormat.rounded(value) }
}
