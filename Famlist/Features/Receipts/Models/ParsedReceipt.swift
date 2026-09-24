/*
 ParsedReceipt.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergebnis des Bon-Parsers: Laden, Datum, Positionen mit Preis, Summe.

 🔰 Notes for Beginners:
 - Preise als Decimal (keine Rundungsfehler bei Cent-Beträgen).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

struct ParsedReceipt: Equatable {
    struct Line: Equatable, Identifiable {
        let id = UUID()
        /// Text wie auf dem Bon, z. B. „KERRYGOLD BUTTER“.
        let raw: String
        let price: Decimal

        static func == (l: Line, r: Line) -> Bool { l.raw == r.raw && l.price == r.price }
    }

    var store: String?
    var date: Date?
    var lines: [Line]
    /// Summe laut Bon („SUMME“ / „ZU ZAHLEN“); fehlt sie, die Summe der Positionen.
    var total: Decimal?

    var computedTotal: Decimal { lines.reduce(0) { $0 + $1.price } }
}
