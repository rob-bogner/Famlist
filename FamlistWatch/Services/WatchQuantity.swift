/*
 WatchQuantity.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengentexte wie auf dem iPhone (ItemModel.quantityText): „6“, „500 g“, „2 Packung“. Einheiten kommen
   übersetzt aus Localizable.xcstrings (mit dem iPhone geteilt).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

enum WatchQuantity {
    /// Wie ItemModel.quantityText auf dem iPhone: ohne Einheit nur die Zahl.
    static func text(units: Double, measure: String) -> String {
        let amount = QuantityFormat.format(units)                // „1,5“ wie auf dem iPhone
        guard !measure.isEmpty else { return amount }
        return "\(amount) \(Measure.fromExternal(measure).localizedName)"
    }

    /// Einheit für den Stepper im Screen „Artikel“ (ohne Einheit: „Stück“).
    static func unitName(measure: String) -> String {
        (measure.isEmpty ? Measure.piece : Measure.fromExternal(measure)).localizedName
    }
}
