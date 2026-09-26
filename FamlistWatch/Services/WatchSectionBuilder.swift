/*
 WatchSectionBuilder.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abschnitte der Uhr-Liste: nach Kategorie in Ladenweg-Reihenfolge (dieselbe Regel wie das iPhone,
   CategoryResolver), innerhalb alphabetisch. Erledigte Artikel bleiben in ihrem Abschnitt (Design).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

enum WatchSectionBuilder {
    static func sections(_ items: [ItemModel], categories: [CategoryDefinition]) -> [WatchSectionDisplay] {
        let order = categories.isEmpty ? CategoryDefinition.defaults : categories
        let grouped = Dictionary(grouping: items) { CategoryResolver.name(for: $0.category, in: order) }
        return order.compactMap { category in
            guard let group = grouped[category.name], !group.isEmpty else { return nil }
            let rows = group.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { WatchItemDisplay(id: $0.id, name: $0.name,
                                        quantity: WatchQuantity.text(units: $0.units, measure: $0.measure),
                                        isChecked: $0.isChecked) }
            return WatchSectionDisplay(title: category.name, items: rows)
        }
    }

    /// Status einer Liste im Screen „Listen“: „4 von 6 offen“, „3 offen“, „erledigt“.
    static func status(open: Int, total: Int) -> String {
        if total == 0 { return "Keine Artikel" }
        if open == 0 { return "erledigt" }
        if open == total { return "\(open) offen" }
        return "\(open) von \(total) offen"
    }
}
