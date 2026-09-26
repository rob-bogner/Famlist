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
    static func text(units: Int, measure: String) -> String {
        guard !measure.isEmpty else { return "\(units)" }
        return "\(units) \(Measure.fromExternal(measure).localizedName)"
    }

    /// Einheit für den Stepper im Screen „Artikel“ (ohne Einheit: „Stück“).
    static func unitName(measure: String) -> String {
        (measure.isEmpty ? Measure.piece : Measure.fromExternal(measure)).localizedName
    }
}
