/*
 ListSection.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Abschnitt der Liste, wie ihn ShoppingListContent zeichnet: Kategorie (mit Kopf „Alle abhaken ›“),
   „Abgehakt“ (Kopf ohne Aktion) oder eine flache Liste ohne Kopf.

 🔰 Notes for Beginners:
 - Welche Abschnitte es gibt, entscheidet ListSectionBuilder aus Sortier-Einstellung und Tab.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Sortieren).
 ------------------------------------------------------------------------
 */

import Foundation

/// A rendered section of the shopping list.
struct ListSection: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Kategorie-Gruppe (Sortierung „Nach Kategorie“), Reihenfolge = Ladenweg des Nutzers.
        case category(CategoryDefinition)
        /// Abgehakte Artikel unten („Erledigte nach unten“).
        case checked
        /// Flache Liste ohne Kopf (Alphabetisch, Zuletzt hinzugefügt, Manuell).
        case flat
    }

    let kind: Kind
    let items: [ItemModel]

    var id: String {
        switch kind {
        case .category(let category): return "category-\(category.id.uuidString)"
        case .checked: return "checked"
        case .flat: return "flat"
        }
    }
}
