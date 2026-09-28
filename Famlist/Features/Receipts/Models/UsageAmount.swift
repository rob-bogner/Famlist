/*
 UsageAmount.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Verbrauchsmenge in einer Einheitsart: Gewicht (in g), Volumen (in ml), eine Zähleinheit
   („piece“, „pack“ …) oder reine Stückzahl.

 🔰 Notes for Beginners:
 - Gewicht und Volumen werden in der kleinsten Einheit addiert (500 g + 1 kg = 1500 g) und für die Anzeige
   ab 1000 in kg bzw. l umgerechnet (InsightFormat/UsageInsightsText).
 - `.pieces` = Stückzahl laut Bon; gilt, wenn Einheiten eines Artikels nicht zusammenpassen oder unbekannt sind.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct UsageAmount: Equatable {
    enum Kind: Equatable {
        case mass
        case volume
        /// Zähleinheit aus dem Artikel („piece“, „pack“, „bottle“ …).
        case unit(String)
        case pieces
    }

    let kind: Kind
    /// In g (mass), ml (volume), sonst in der Einheit bzw. Stück.
    let value: Double

    static let zero = UsageAmount(kind: .pieces, value: 0)

    /// Menge einer Bon-Zeile; ohne Inhalt je Stück nur die Stückzahl.
    static func of(_ line: ReceiptLine) -> UsageAmount {
        let quantity = Double(max(line.quantity, 1))
        guard let units = line.units, units > 0, let measure = line.measure, !measure.isEmpty else {
            return UsageAmount(kind: .pieces, value: quantity)
        }
        let total = units * quantity
        switch Measure.fromExternal(measure) {
        case .g: return UsageAmount(kind: .mass, value: total)
        case .kg: return UsageAmount(kind: .mass, value: total * 1000)
        case .ml: return UsageAmount(kind: .volume, value: total)
        case .l: return UsageAmount(kind: .volume, value: total * 1000)
        case let other: return UsageAmount(kind: .unit(other.rawValue), value: total)
        }
    }

    /// Summe mehrerer Zeilen; passen die Einheitsarten nicht zusammen, zählt die Stückzahl.
    static func sum(_ lines: [ReceiptLine]) -> UsageAmount {
        let parts = lines.map(of)
        guard let kind = parts.first?.kind else { return .zero }
        if parts.allSatisfy({ $0.kind == kind }) {
            return UsageAmount(kind: kind, value: parts.reduce(0) { $0 + $1.value })
        }
        return UsageAmount(kind: .pieces, value: Double(lines.reduce(0) { $0 + max($1.quantity, 1) }))
    }
}
