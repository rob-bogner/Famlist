/*
 ListClipboardFormatter.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Erzeugt den Text für „In Zwischenablage kopieren“: erste Zeile Listenname,
   dann je Artikel „• Name · Menge Einheit“ (SPEC §3.4).

 🔰 Notes for Beginners:
 - Beispiel aus dem Design (CopyChoice): "My List\n• Butter · 1 Packung".
 - Ohne Einheit und mit Menge 1 entfällt der Teil nach „·“ („• Brot“).
 - Die Reihenfolge ist die der Liste auf dem Bildschirm (Abschnitte von oben nach unten).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Dock „Kopieren“).
 ------------------------------------------------------------------------
 */

import Foundation

/// Plain-text export of a shopping list for the clipboard.
enum ListClipboardFormatter {
    enum Scope {
        /// „Offene Artikel – Was noch gekauft werden muss“
        case open
        /// „Alle Artikel – Inklusive abgehakter“
        case all
    }

    static func items(_ items: [ItemModel], scope: Scope) -> [ItemModel] {
        scope == .open ? items.filter { !$0.isChecked } : items
    }

    static func text(listTitle: String, items: [ItemModel], scope: Scope) -> String {
        let lines = self.items(items, scope: scope).map(line(for:))
        return ([listTitle] + lines).joined(separator: "\n")
    }

    static func line(for item: ItemModel) -> String {
        let name = item.name.trimmingCharacters(in: .whitespaces)
        if item.measure.isEmpty && item.units == 1 { return "• \(name)" }
        return "• \(name) · \(item.quantityText)"
    }
}
