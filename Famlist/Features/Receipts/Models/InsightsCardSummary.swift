/*
 InsightsCardSummary.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zahlen der Karte „Auswertung <Monat>“ oben im Kassenzettel-Archiv (Board ReceiptArchiveInsights).

 🔰 Notes for Beginners:
 - Monat = aktueller Monat; gibt es darin keinen Bon, der letzte Monat mit Bons (ReceiptInsights.defaultMonth).
 - Ohne Bons gibt es keine Karte (`make` liefert nil).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct InsightsCardSummary: Equatable {
    let month: Date
    let total: Decimal
    let count: Int

    static func make(_ receipts: [ArchivedReceipt], now: Date = Date()) -> InsightsCardSummary? {
        guard let month = ReceiptInsights.defaultMonth(receipts, now: now) else { return nil }
        let inMonth = ReceiptInsights.receipts(receipts, in: month)
        return InsightsCardSummary(month: month, total: inMonth.reduce(Decimal(0)) { $0 + $1.total }, count: inMonth.count)
    }

    /// „Auswertung September“
    var title: String { "Auswertung \(InsightFormat.month(month))" }

    /// „412,37 € · 9 Einkäufe“
    var value: String {
        "\(InsightFormat.euro(total)) · " + (count == 1 ? "1 Einkauf" : "\(count) Einkäufe")
    }

    static let subtitle = "Ausgaben und Verbrauch"
}
