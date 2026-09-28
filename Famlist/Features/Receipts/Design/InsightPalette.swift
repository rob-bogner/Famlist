/*
 InsightPalette.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kategoriefarben für Bon-Detail und Auswertung (RECEIPT_INSIGHTS_PROMPT.md §5), Hell und Dunkel.

 🔰 Notes for Beginners:
 - Farbe nach Rang der Kategorie (CategoryColorRanking): Rang 0 → erste Farbe; ab Rang 6 beginnt die Reihe neu.
 - „Sonstiges“ und Zeilen ohne Kategorie sind immer grau.
 - Kachel-Hintergrund = Kategoriefarbe mit 12 % (Hell) bzw. 18 % (Dunkel) Deckkraft, wie `cs.*` im Board.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum InsightPalette {
    /// (Hell, Dunkel) je Rang.
    static let ranked: [(light: String, dark: String)] = [
        ("#3FA66B", "#5BC98A"),
        ("#4F86E8", "#7AA6F5"),
        ("#D9534F", "#F07C78"),
        ("#8466E8", "#A58CF5"),
        ("#D99A2B", "#F0B654"),
        ("#E0679E", "#F08DB9")
    ]
    static let other = (light: "#93A5A8", dark: "#6F8588")

    /// Farbe für einen Rang; nil = „Sonstiges“ / ohne Kategorie.
    static func hex(rank: Int?, dark: Bool) -> String {
        guard let rank, rank >= 0 else { return dark ? other.dark : other.light }
        let pair = ranked[rank % ranked.count]
        return dark ? pair.dark : pair.light
    }

    static func color(rank: Int?, dark: Bool) -> Color { .hex(hex(rank: rank, dark: dark)) }

    /// Kachel-Hintergrund (`cs.*`): 12 % Hell, 18 % Dunkel.
    static func soft(rank: Int?, dark: Bool) -> Color { .hex(hex(rank: rank, dark: dark), dark ? 0.18 : 0.12) }
}
