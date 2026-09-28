/*
 CategoryColorRanking.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rang jeder Kategorie über alle Bons des Archivs (nach Betrag). Daraus kommt die Kategoriefarbe
   (InsightPalette) – gleich in Bon-Detail, Ausgaben und Verbrauch.

 🔰 Notes for Beginners:
 - Ein Rang je Kategorie-Name, stabil für alle Monate: Obst & Gemüse bleibt grün, egal welcher Monat gezeigt wird.
 - „Sonstiges“ und Zeilen ohne Kategorie bekommen keinen Rang (grau).
 - Gleicher Betrag → alphabetisch, damit die Reihenfolge nicht springt.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct CategoryColorRanking: Equatable {
    let ranks: [String: Int]

    static let empty = CategoryColorRanking(ranks: [:])

    /// `lines`: alle Bon-Zeilen des Archivs, bereits mit Kategorie ergänzt (ReceiptLineEnricher).
    static func make(lines: [ReceiptLine]) -> CategoryColorRanking {
        var sums: [String: Decimal] = [:]
        for line in lines {
            guard let name = line.category, !isOther(name) else { continue }
            sums[name, default: 0] += line.price
        }
        let order = sums.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
        return CategoryColorRanking(ranks: Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) }))
    }

    /// Rang einer Kategorie; nil = grau.
    func rank(of category: String?) -> Int? {
        guard let category, !Self.isOther(category) else { return nil }
        return ranks[category]
    }

    static func isOther(_ category: String) -> Bool {
        category.caseInsensitiveCompare(CategoryDefinition.fallbackName) == .orderedSame
    }
}
