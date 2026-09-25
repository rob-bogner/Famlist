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
 - `lineTotal` rechnet Preis × Menge; die Fortschrittskarte summiert das über alle Artikel.

 📝 Last Change:
 - Neu angelegt (Preise in Liste und Fortschrittskarte, Design Hybrid/Settings).
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

    /// Preis × Menge eines Artikels; mindestens Menge 1.
    static func lineTotal(_ item: ItemModel) -> Double {
        max(item.price, 0) * Double(max(item.units, 1))
    }
}
