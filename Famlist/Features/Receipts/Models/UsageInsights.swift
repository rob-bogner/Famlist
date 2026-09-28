/*
 UsageInsights.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergebnis der Auswertung „Verbrauch“ für einen Monat (Board InsightUsage): gekaufte Produkte mit Menge,
   Kosten, Verlauf über 6 Monate und Veränderung zum Vormonat.

 🔰 Notes for Beginners:
 - Nur zugeordnete Bon-Zeilen zählen (ohne Artikel kein Verbrauch).
 - `hero` = Produkt mit der größten Stückzahl im Monat (bei Gleichstand die höheren Kosten).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct UsageInsights: Equatable {
    struct Product: Equatable, Identifiable {
        /// Name-Schlüssel wie im Preisverlauf (PricePoint.key).
        let key: String
        let name: String
        let category: String?
        let rank: Int?
        /// Anzahl Käufe (Bon-Zeilen) im Monat.
        let purchases: Int
        /// Stückzahl laut Bon.
        let pieces: Int
        let cost: Decimal
        let amount: UsageAmount
        /// Menge im Vormonat in derselben Einheitsart; nil, wenn sie nicht vergleichbar ist.
        let previous: UsageAmount?
        /// Menge je Monat, ältester zuerst, der gewählte Monat zuletzt (6 Werte, 0 = nicht gekauft).
        let history: [Double]
        var id: String { key }
    }

    let month: Date
    let previousMonth: Date
    /// Sortiert nach Käufen, dann Kosten.
    let products: [Product]

    var hero: Product? {
        products.max { ($0.pieces, $0.cost) < ($1.pieces, $1.cost) }
    }

    var isEmpty: Bool { products.isEmpty }
}
