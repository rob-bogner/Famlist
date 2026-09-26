/*
 ParsedReceipt.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergebnis des Bon-Parsers: Laden, Datum, Positionen mit Preis und Stückzahl, Summe.

 🔰 Notes for Beginners:
 - Preise als Decimal (keine Rundungsfehler bei Cent-Beträgen).
 - `price` ist der Betrag der Zeile („BANANEN 2,58“); stand eine Mengenzeile dabei („2 Stk x 1,29“),
   ist `quantity` 2 und `unitPrice(price:quantity:)` liefert 1,29 € je Stück.

 📝 Last Change:
 - Stückzahl je Position (für Stückpreise im Preisverlauf und als Artikelpreis).
 ------------------------------------------------------------------------
 */

import Foundation

struct ParsedReceipt: Equatable {
    struct Line: Equatable, Identifiable {
        let id = UUID()
        /// Text wie auf dem Bon, z. B. „KERRYGOLD BUTTER“.
        let raw: String
        let price: Decimal
        /// Stückzahl aus einer Mengenzeile („2 Stk x 1,29“), sonst 1.
        var quantity: Int = 1

        static func == (l: Line, r: Line) -> Bool { l.raw == r.raw && l.price == r.price && l.quantity == r.quantity }
    }

    var store: String?
    var date: Date?
    var lines: [Line]
    /// Summe laut Bon („SUMME“ / „ZU ZAHLEN“); fehlt sie, die Summe der Positionen.
    var total: Decimal?

    var computedTotal: Decimal { lines.reduce(0) { $0 + $1.price } }

    /// Preis je Stück, auf Cent gerundet: 2,58 € bei 2 Stück → 1,29 €.
    static func unitPrice(price: Decimal, quantity: Int) -> Decimal {
        guard quantity > 1 else { return price }
        var exact = price / Decimal(quantity)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, 2, .plain)
        return rounded
    }
}
