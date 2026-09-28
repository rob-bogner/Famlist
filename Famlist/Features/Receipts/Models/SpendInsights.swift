/*
 SpendInsights.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergebnis der Auswertung „Ausgaben“ für einen Monat (Board InsightSpend): Summe, Einkäufe, Schnitt,
   Veränderung zum Vormonat, 6 Monatssäulen, Anteile je Kategorie und je Laden.

 🔰 Notes for Beginners:
 - Wird von ReceiptInsights berechnet; enthält nur fertige Zahlen, keine Texte.
 - Die verschachtelten Typen gehören nur hierher (eine Zeile der Säulen, der Kategorien, der Läden).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct SpendInsights: Equatable {
    struct MonthBar: Equatable, Identifiable {
        /// Erster Tag des Monats (Europe/Berlin).
        let month: Date
        let total: Decimal
        let hasReceipts: Bool
        let isSelected: Bool
        var id: Date { month }
    }

    struct CategoryShare: Equatable, Identifiable {
        let name: String
        let amount: Decimal
        /// Anteil an der Monatssumme in ganzen Prozent.
        let percent: Int
        /// Farbrang (CategoryColorRanking); nil bei „Sonstiges“.
        let rank: Int?
        let isOther: Bool
        var id: String { name }
    }

    struct StoreShare: Equatable, Identifiable {
        let name: String
        let count: Int
        let total: Decimal
        let average: Decimal
        /// Länge des Balkens relativ zum Laden mit der größten Summe (0…1).
        let fraction: Double
        var id: String { name }
    }

    let month: Date
    let previousMonth: Date
    let total: Decimal
    let count: Int
    /// Summe ÷ Einkäufe; nil ohne Einkäufe.
    let average: Decimal?
    /// Veränderung zur Summe des Vormonats in ganzen Prozent; nil, wenn der Vormonat keine Bons hat.
    let changePercent: Int?
    let bars: [MonthBar]
    /// Schnitt der Monate mit Bons unter den 6 Säulen; nil, wenn keiner Bons hat.
    let barAverage: Decimal?
    let categories: [CategoryShare]
    let stores: [StoreShare]

    var isEmpty: Bool { count == 0 }
}
