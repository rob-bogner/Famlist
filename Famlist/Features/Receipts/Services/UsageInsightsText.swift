/*
 UsageInsightsText.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Texte der Auswertung „Verbrauch“ (Board InsightUsage): Mengen („14 l“, „4,2 kg“, „30 Stück“),
   Veränderung („+2 l“, „−1“, „±0“), Hero („Milch im September · 14 Liter“) und seine Chips.

 🔰 Notes for Beginners:
 - Gewicht/Volumen ab 1000 g bzw. 1000 ml in kg bzw. l; Veränderung in derselben Einheit wie die Menge.
 - Zähleinheiten zeigen die Veränderung ohne Einheit („+2“), wie im Board.
 - „pro Woche“ = Monatsmenge ÷ (Tage im Monat ÷ 7), eine Nachkommastelle (Auftrag „Berechnungen“).
 - Minus als echtes Minuszeichen (U+2212), wie im Board.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum UsageInsightsText {
    static let notFound = "Kein Produkt gefunden"

    /// Anzeigeeinheit und Faktor: 1500 g → („kg“, 1000).
    private static func unit(for amount: UsageAmount) -> (name: String, long: String, factor: Double) {
        switch amount.kind {
        case .mass: return amount.value >= 1000 ? ("kg", "Kilogramm", 1000) : ("g", "Gramm", 1)
        case .volume: return amount.value >= 1000 ? ("l", "Liter", 1000) : ("ml", "Milliliter", 1)
        case .unit(let key):
            let name = InsightFormat.unit(key) ?? "Stück"
            return (name, name, 1)
        case .pieces: return ("Stück", "Stück", 1)
        }
    }

    /// „14 l“, „4,2 kg“, „30 Stück“
    static func amount(_ amount: UsageAmount) -> String {
        let u = unit(for: amount)
        return "\(QuantityFormat.format(amount.value / u.factor)) \(u.name)"
    }

    /// „14 Liter“ (Hero, Einheit ausgeschrieben).
    static func heroAmount(_ amount: UsageAmount) -> String {
        let u = unit(for: amount)
        return "\(QuantityFormat.format(amount.value / u.factor)) \(u.long)"
    }

    /// „+2 l“, „−0,5 kg“, „+2“, „±0“; nil ohne vergleichbaren Vormonat.
    static func delta(_ product: UsageInsights.Product) -> String? {
        guard let previous = product.previous else { return nil }
        let u = unit(for: product.amount)
        let difference = QuantityFormat.normalized((product.amount.value - previous.value) / u.factor)
        guard difference != 0 else { return "±0" }
        let number = QuantityFormat.format(abs(difference))
        let sign = difference > 0 ? "+" : "\u{2212}"
        return isCount(product.amount) ? "\(sign)\(number)" : "\(sign)\(number) \(u.name)"
    }

    /// 1 = mehr, −1 = weniger, 0 = gleich/unbekannt (Pfeil neben der Veränderung).
    static func direction(_ product: UsageInsights.Product) -> Int {
        guard let previous = product.previous else { return 0 }
        let difference = product.amount.value - previous.value
        return abs(difference) < 0.0001 ? 0 : (difference > 0 ? 1 : -1)
    }

    private static func isCount(_ amount: UsageAmount) -> Bool {
        switch amount.kind {
        case .mass, .volume: return false
        case .unit, .pieces: return true
        }
    }

    // MARK: - Hero

    static func heroTitle(_ usage: UsageInsights) -> String {
        "\(usage.hero?.name ?? "Verbrauch") im \(InsightFormat.month(usage.month))"
    }

    static func heroValue(_ usage: UsageInsights) -> String {
        usage.hero.map { heroAmount($0.amount) } ?? InsightFormat.euro(0)
    }

    static func chips(_ usage: UsageInsights, calendar: Calendar = ReceiptTimes.calendar) -> [String] {
        guard let hero = usage.hero else { return [SpendInsightsText.noPurchases] }
        var chips = ["\(perWeek(hero.amount, month: usage.month, calendar: calendar)) pro Woche"]
        if let delta = delta(hero) {
            let arrow = SpendInsightsText.arrow(direction(hero))
            let text = delta == "±0" ? "±0" : String(delta.dropFirst())
            chips.append(delta == "±0" ? "\(text) ggü. \(InsightFormat.month(usage.previousMonth))"
                         : "\(arrow) \(text) ggü. \(InsightFormat.month(usage.previousMonth))")
        }
        chips.append(InsightFormat.euro(hero.cost))
        return chips
    }

    /// „3,3 l“: Monatsmenge ÷ (Tage im Monat ÷ 7), eine Nachkommastelle.
    static func perWeek(_ amount: UsageAmount, month: Date, calendar: Calendar = ReceiptTimes.calendar) -> String {
        let days = Double(calendar.range(of: .day, in: .month, for: month)?.count ?? 30)
        let u = unit(for: amount)
        let weekly = ((amount.value / u.factor) / (days / 7) * 10).rounded() / 10
        return "\(QuantityFormat.format(weekly)) \(u.name)"
    }

    /// VoiceOver je Zeile: „Milch, 14 l im September, 16,66 €“ (aria-label im Board).
    static func accessibility(_ product: UsageInsights.Product, month: Date) -> String {
        "\(product.name), \(amount(product.amount)) im \(InsightFormat.month(month)), \(InsightFormat.euro(product.cost))"
    }
}
