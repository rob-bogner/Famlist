/*
 ListViewModel+CategoryProjections.swift

 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kategoriebasierte Gruppierungs-Projektionen auf bestehenden ItemModel-Daten.
 - Reine Darstellungslogik, kein Netzwerk- oder Repository-Zugriff.

 🛠 Includes:
 - uncheckedItemsByCategory: Unerledige Items in Supermarkt-Reihenfolge gruppiert

 📝 Last Change:
 - Initial creation (FAM-64)
 ------------------------------------------------------------------------
*/

import Foundation

extension ListViewModel {

    /// Unerleidigte Items gruppiert nach Kategorie in Supermarkt-Anzeigereihenfolge.
    /// Kategorien ohne Items werden ausgelassen.
    var uncheckedItemsByCategory: [(category: ItemCategory, items: [ItemModel])] {
        let grouped = Dictionary(grouping: uncheckedItems) {
            ItemCategory.from($0.category)
        }
        return ItemCategory.displayOrder.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }
}
