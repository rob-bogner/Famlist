/*
 ListTextFilter.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Textfilter für die Liste (Suchleiste oben): welche Artikel zum Suchbegriff passen.

 🔰 Notes for Beginners:
 - Reine Funktionen, dadurch testbar. Groß/klein und Akzente werden ignoriert („apfel“ findet „Äpfel“).
 - Durchsucht Name und Marke; offene und abgehakte Artikel (Canvas: „auch abgehakte“).

 📝 Last Change:
 - Initial creation (Suche → Filter).
 ------------------------------------------------------------------------
 */

import Foundation

enum ListTextFilter {
    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ item: ItemModel, query: String) -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return true }
        if item.name.range(of: q, options: options) != nil { return true }
        if let brand = item.brand, brand.range(of: q, options: options) != nil { return true }
        return false
    }

    /// Treffer in der gegebenen Reihenfolge (Listenreihenfolge: offene nach Kategorie, dann abgehakte).
    static func filter(_ items: [ItemModel], query: String) -> [ItemModel] {
        items.filter { matches($0, query: query) }
    }
}
