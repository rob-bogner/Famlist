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
    let units: Double
    let measure: String
    var id: String { label }
}

enum QuantityPresets {
    /// Bereich der ± -Knöpfe. Untergrenze 1 – bei feinen Schritten (0,1 kg) die Schrittweite selbst (`minimum`).
    /// Kleinere Mengen sonst nur per Eingabe (QuantityFormat.range).
    static let range: ClosedRange<Double> = 1...9999

    /// Feiner Schritt: einmal tippen bzw. Krone langsam drehen. kg/l/m 0,1 · g/ml 50 · sonst 1.
    static func step(for measure: String) -> Double {
        switch Measure.fromExternal(measure) {
        case .g, .ml: return 50
        case .kg, .l, .m: return 0.1
        default: return 1
        }
    }

    /// Grober Schritt: Knopf gedrückt halten bzw. Krone schnell drehen. kg/l/m 1 · sonst wie `step`.
    static func coarseStep(for measure: String) -> Double {
        switch Measure.fromExternal(measure) {
        case .kg, .l, .m: return 1
        default: return step(for: measure)
        }
    }

    /// Kleinster Wert, den „−“ erreicht: die Schrittweite, wenn sie unter 1 liegt (0,1 kg), sonst 1.
    static func minimum(forStep step: Double) -> Double {
        step < 1 ? step : range.lowerBound
    }

    /// Nächster Wert: rastet auf Vielfache der Schrittweite ein und bleibt im Bereich
    /// (1,5 + 1 → 2, 1,5 + 0,1 → 1,6, 120 g + 50 → 150). Unter `minimum` senkt „−“ nicht weiter ab.
    static func next(_ value: Double, up: Bool, step: Double) -> Double {
        let value = QuantityFormat.normalized(value)
        let lower = minimum(forStep: step)
        if !up && value <= lower { return value }
        let steps = QuantityFormat.normalized(value / step)
        let snapped = up ? (steps.rounded(.down) + 1) * step : (steps.rounded(.up) - 1) * step
        return min(max(QuantityFormat.normalized(snapped), lower), range.upperBound)
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
            return ([1, 2, 5] as [Int]).map { .init(label: "\($0) kg", units: Double($0), measure: "kg") }
        case .l:
            return ([1, 2, 6] as [Int]).map { .init(label: "\($0) l", units: Double($0), measure: "l") }
        default:
            return ([2, 6, 10] as [Int]).map { .init(label: "\($0)", units: Double($0), measure: measure) }
        }
    }
}
