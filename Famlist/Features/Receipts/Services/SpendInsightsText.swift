/*
 SpendInsightsText.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Texte der Auswertung „Ausgaben“ (Board InsightSpend): Hero, Chips, Säulen, Kategorien, Läden.

 🔰 Notes for Beginners:
 - Monat ohne Bons: Hero „0,00 €“ mit Chip „Keine Einkäufe“ (Auftrag §6, nicht gestaltet).
 - Veränderung zum Vormonat: „↑ 8 % ggü. August“, „↓ 5 % ggü. August“, „±0 % ggü. August“; ohne Vormonat kein Chip.
 - Reine Funktionen → Unit-Tests.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum SpendInsightsText {
    static let noPurchases = "Keine Einkäufe"

    /// „Ausgegeben im September“
    static func heroTitle(_ spend: SpendInsights) -> String {
        "Ausgegeben im \(InsightFormat.month(spend.month))"
    }

    static func heroValue(_ spend: SpendInsights) -> String {
        InsightFormat.euro(spend.total)
    }

    static func chips(_ spend: SpendInsights) -> [String] {
        guard !spend.isEmpty else { return [noPurchases] }
        var chips: [String] = []
        if let change = spend.changePercent {
            chips.append("\(arrow(change)) \(abs(change)) % ggü. \(InsightFormat.month(spend.previousMonth))")
        }
        chips.append(spend.count == 1 ? "1 Einkauf" : "\(spend.count) Einkäufe")
        if let average = spend.average { chips.append("Ø \(InsightFormat.euro(average))") }
        return chips
    }

    /// ↑ mehr, ↓ weniger, ± gleich (Werte ohne Vorzeichen dahinter).
    static func arrow(_ change: Int) -> String {
        change > 0 ? "↑" : change < 0 ? "↓" : "±"
    }

    /// „Ø 385 €“ über den Säulen; ohne Monate mit Bons leer.
    static func barAverage(_ spend: SpendInsights) -> String {
        spend.barAverage.map { "Ø \(InsightFormat.wholeEuro($0))" } ?? ""
    }

    /// Betrag über der Säule: „412“.
    static func barValue(_ bar: SpendInsights.MonthBar) -> String {
        InsightFormat.wholeEuro(bar.total).replacingOccurrences(of: " €", with: "")
    }

    /// „23 %“
    static func percent(_ share: SpendInsights.CategoryShare) -> String { "\(share.percent) %" }

    /// „4 × · Ø 39,55 €“
    static func storeDetail(_ store: SpendInsights.StoreShare) -> String {
        "\(store.count) × · Ø \(InsightFormat.euro(store.average))"
    }

    /// VoiceOver je Säule: „April: 356 Euro“.
    static func barAccessibility(_ bar: SpendInsights.MonthBar) -> String {
        "\(InsightFormat.month(bar.month)): \(barValue(bar)) Euro" + (bar.isSelected ? ", ausgewählt" : "")
    }
}
