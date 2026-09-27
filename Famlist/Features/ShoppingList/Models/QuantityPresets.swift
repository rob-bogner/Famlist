/*
 QuantityPresets.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengen-Eingabe passend zur Einheit (Canvas „Artikel bearbeiten – Menge eintippen“):
   Schrittweite für − / + und die Schnellwahl über dem Ziffernblock.

 🔰 Notes for Beginners:
 - Reine Funktionen, dadurch testbar.
 - Gramm/Milliliter: Schritt 50, Schnellwahl 100 g · 250 g · 500 g · 1 kg (1 kg wechselt die Einheit).
 - Alles andere: Schritt 1. Die Menge ist eine ganze Zahl (ItemModel.units), halbe Kilo gibt es daher nicht.
 - ± rastet auf Vielfache der Schrittweite ein (1 g + → 50 g, 120 g − → 100 g), nie unter 1.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import Foundation

struct QuantityPreset: Equatable, Identifiable {
    let label: String
    let units: Int
    let measure: String
    var id: String { label }
}

enum QuantityPresets {
    static let range: ClosedRange<Int> = 1...9999

    /// Schrittweite der ± -Knöpfe.
    static func step(for measure: String) -> Int {
        switch Measure.fromExternal(measure) {
        case .g, .ml: return 50
        default: return 1
        }
    }

    /// Nächster Wert: rastet auf Vielfache der Schrittweite ein und bleibt in `range`.
    static func next(_ value: Int, up: Bool, step: Int) -> Int {
        guard step > 1 else { return min(max(value + (up ? 1 : -1), range.lowerBound), range.upperBound) }
        let snapped = up ? (value / step + 1) * step : ((value - 1) / step) * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    /// Schnellwahl über dem Ziffernblock.
    static func presets(for measure: String) -> [QuantityPreset] {
        switch Measure.fromExternal(measure) {
        case .g:
            return [.init(label: "100 g", units: 100, measure: "g"), .init(label: "250 g", units: 250, measure: "g"),
                    .init(label: "500 g", units: 500, measure: "g"), .init(label: "1 kg", units: 1, measure: "kg")]
        case .ml:
            return [.init(label: "250 ml", units: 250, measure: "ml"), .init(label: "500 ml", units: 500, measure: "ml"),
                    .init(label: "1 l", units: 1, measure: "l")]
        case .kg:
            return [1, 2, 5].map { .init(label: "\($0) kg", units: $0, measure: "kg") }
        case .l:
            return [1, 2, 6].map { .init(label: "\($0) l", units: $0, measure: "l") }
        default:
            return [2, 6, 10].map { .init(label: "\($0)", units: $0, measure: measure) }
        }
    }
}
