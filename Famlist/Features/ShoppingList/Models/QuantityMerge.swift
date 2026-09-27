/*
 QuantityMerge.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Menge zusammenführen, wenn ein Artikel erneut hinzukommt (Duplikat oder Import in einen offenen Artikel).

 🔰 Notes for Beginners:
 - Gleiche oder keine Einheit → addieren (1 kg + 0,5 kg = 1,5 kg).
 - Umrechenbare Einheiten (g↔kg, ml↔l, cm↔m) → umrechnen und addieren (500 g + 1 kg = 1,5 kg).
   Ergebnis bevorzugt in der zuletzt eingegebenen Einheit; passt es dort nicht (mehr als 2 Nachkommastellen oder
   über 9999), in der anderen (5 g + 1 kg = 1005 g).
 - Nicht umrechenbar (Stück + g) → die neue Eingabe gilt.
 - Entscheidung Robert, 27.09.2026 (vorher ergab 500 g + 1 kg „501“).

 📝 Last Change:
 - Neu.
 ------------------------------------------------------------------------
 */

import Foundation

enum QuantityMerge {
    /// Menge in einer Einheit (Einheit als gespeicherter Text, z. B. "kg").
    typealias Amount = (units: Double, measure: String)

    /// Faktor zur kleinsten Einheit derselben Größe (1 kg = 1000 g).
    private static let factors: [Measure: (base: Measure, factor: Double)] = [
        .g: (.g, 1), .kg: (.g, 1000),
        .ml: (.ml, 1), .l: (.ml, 1000),
        .cm: (.cm, 1), .m: (.cm, 100),
    ]

    /// Menge und Einheit, nachdem `added` zu `existing` hinzugekommen ist.
    static func combine(existing: Amount, added: Amount) -> Amount {
        let upper = QuantityFormat.range.upperBound
        if added.measure.isEmpty || Measure.fromExternal(existing.measure) == Measure.fromExternal(added.measure) {
            return (min(QuantityFormat.normalized(existing.units + added.units), upper), existing.measure)
        }
        guard let e = factors[Measure.fromExternal(existing.measure)],
              let a = factors[Measure.fromExternal(added.measure)], e.base == a.base else {
            return added                                            // nicht umrechenbar → neue Eingabe gilt
        }
        let totalInBase = existing.units * e.factor + added.units * a.factor
        for (measure, factor) in [(added.measure, a.factor), (existing.measure, e.factor)] {
            let value = totalInBase / factor
            if value <= upper && abs(QuantityFormat.normalized(value) - value) < 1e-9 {
                return (QuantityFormat.normalized(value), measure)
            }
        }
        // Passt in keiner der beiden genau: größere Einheit, auf 2 Stellen gerundet.
        let (measure, factor) = a.factor >= e.factor ? (added.measure, a.factor) : (existing.measure, e.factor)
        return (min(QuantityFormat.normalized(totalInBase / factor), upper), measure)
    }
}
