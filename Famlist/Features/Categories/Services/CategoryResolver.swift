/*
 CategoryResolver.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ordnet den gespeicherten Kategorie-Text eines Artikels einer Kategorie des Nutzers zu.

 🔰 Notes for Beginners:
 - Reihenfolge: exakter Name (ohne Groß/Klein) → alte Schreibweisen über ItemCategory.from
   („Molkerei“, englische Werte) → sonst „Sonstiges“.
 - In geteilten Listen kann ein Artikel eine Kategorie haben, die man selbst nicht kennt → „Sonstiges“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

enum CategoryResolver {
    /// Kategorie aus `defs`, zu der ein Artikel gehört (nie nil, solange `defs` „Sonstiges“ enthält).
    static func category(for raw: String?, in defs: [CategoryDefinition]) -> CategoryDefinition? {
        let fallback = defs.first(where: \.isFallback) ?? defs.last
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return fallback }
        if let exact = defs.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) { return exact }
        let legacy = ItemCategory.from(raw).rawValue
        if let mapped = defs.first(where: { $0.name == legacy }) { return mapped }
        return fallback
    }

    static func name(for raw: String?, in defs: [CategoryDefinition]) -> String {
        category(for: raw, in: defs)?.name ?? CategoryDefinition.fallbackName
    }
}
