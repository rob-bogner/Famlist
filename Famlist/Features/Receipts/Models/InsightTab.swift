/*
 InsightTab.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Reiter der Auswertung: „Ausgaben“ (InsightSpend) und „Verbrauch“ (InsightUsage).

 🔰 Notes for Beginners:
 - `rawValue` ist der Index im Segment (SheetSegmentControl).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum InsightTab: Int, CaseIterable, Equatable {
    case spend
    case usage

    var title: String {
        switch self {
        case .spend: return "Ausgaben"
        case .usage: return "Verbrauch"
        }
    }
}
