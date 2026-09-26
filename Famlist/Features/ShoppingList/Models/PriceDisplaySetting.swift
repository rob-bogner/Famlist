/*
 PriceDisplaySetting.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstellung „Preise anzeigen“ (Einstellungen → Liste): Preise auf Artikelkarten und die Summe
   in der Fortschrittskarte ein- oder ausblenden. Dazu die Euro-Formatierung für beide Stellen.

 🔰 Notes for Beginners:
 - Gespeichert per @AppStorage (UserDefaults) unter `storageKey`; Standard ist „an“ (Design: prices = true).
 - `lineTotal` rechnet Preis × Stückzahl; die Fortschrittskarte summiert das über alle Artikel.
 - Bei Gewicht, Volumen und Länge (g, kg, ml, l, cm, m) ist die Menge die Größe EINER Packung
   („500 g Hackfleisch“), keine Stückzahl: Dann zählt der Preis einmal.

 📝 Last Change:
 - Gewicht/Volumen/Länge nicht mehr mit der Menge multipliziert (Audit H8: „500 g“ zu 4,99 € ergab 2.495 €).
 ------------------------------------------------------------------------
 */

import Foundation

/// Speicher-Schlüssel, Standardwert und Formatierung für „Preise anzeigen“.
enum PriceDisplaySetting {
    static let storageKey = "list.showPrices"
    static let defaultValue = true

    /// „1,49 €“ – immer deutsches Format wie im Design.
    static func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
    }

    /// Summe aller Artikel: Preis × Menge (Artikel ohne Preis zählen 0).
    static func total(of items: [ItemModel]) -> Double {
        items.reduce(0) { $0 + lineTotal($1) }
    }

    /// Preis × Stückzahl eines Artikels (siehe `multiplier`).
    static func lineTotal(_ item: ItemModel) -> Double {
        max(item.price, 0) * Double(multiplier(for: item))
    }

    /// Wie oft der Preis zählt: Stückzahl bei Zähl-Einheiten, 1 bei Gewicht/Volumen/Länge.
    static func multiplier(for item: ItemModel) -> Int {
        isMeasuredAmount(item.measure) ? 1 : max(item.units, 1)
    }

    /// true für Einheiten, bei denen die Menge eine Größe ist (g, kg, ml, l, cm, m).
    static func isMeasuredAmount(_ measure: String) -> Bool {
        switch Measure.fromExternal(measure) {
        case .g, .kg, .ml, .l, .cm, .m: return true
        default: return false
        }
    }
}
