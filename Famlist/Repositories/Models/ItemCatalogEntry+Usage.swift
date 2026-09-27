/*
 ItemCatalogEntry+Usage.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Auswahl „Oft gekauft“ aus dem Artikelstamm (Apple Watch, Screen „Hinzufügen“).

 🔰 Notes for Beginners:
 - Reihenfolge: häufigste zuerst (use_count), bei Gleichstand der zuletzt benutzte, dann alphabetisch.
 - Nie hinzugefügte Einträge (Zähler 0 oder unbekannt) erscheinen nicht. Der Zähler beginnt mit
   Migration 022 bei 0, deshalb ist die Auswahl anfangs leer.

 📝 Last Change:
 - Initial creation (Watch-Plan §4, 26.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ItemCatalogEntry {
    /// Anzahl der Einträge unter „Oft gekauft“ (Design: WatchAdd.dc.html).
    static let frequentlyUsedLimit = 8

    /// Die am häufigsten hinzugefügten Einträge, höchstens `limit`.
    static func frequentlyUsed(_ entries: [ItemCatalogEntry], limit: Int = frequentlyUsedLimit) -> [ItemCatalogEntry] {
        let used = entries.filter { ($0.useCount ?? 0) > 0 }
        let sorted = used.sorted { lhs, rhs in
            let lhsCount = lhs.useCount ?? 0, rhsCount = rhs.useCount ?? 0
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            let lhsDate = lhs.lastUsedAt ?? .distantPast, rhsDate = rhs.lastUsedAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return Array(sorted.prefix(max(limit, 0)))
    }
}
