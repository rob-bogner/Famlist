/*
 CheckGestureSetting.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstellung „Artikel abhaken“: Wischen · Kreis · Beides (Design: Settings, SettingsCheckMode, ListSwipeOnly).

 🔰 Notes for Beginners:
 - Gilt nur auf diesem Gerät (@AppStorage wie „Preise anzeigen“), Standard „Beides“ = bisheriges Verhalten.
 - Wischen: kein Kreis auf der Artikelkarte, abhaken nur per Rechts-Wisch.
 - Kreis: Rechts-Wisch aus; die Aktionen beim Links-Wischen bleiben.
 - „Alle abhaken“ und VoiceOver-Aktionen bleiben in jedem Fall erhalten.

 📝 Last Change:
 - Initial creation (Wunsch Robert 29.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

/// How items are checked off in the list.
enum CheckGesture: String, CaseIterable, Identifiable {
    case swipe
    case circle
    case both

    static let storageKey = "list.checkGesture"
    static let defaultValue: CheckGesture = .both

    var id: String { rawValue }

    /// Beschriftung im Segment.
    var label: String {
        switch self {
        case .swipe: return "Wischen"
        case .circle: return "Kreis"
        case .both: return "Beides"
        }
    }

    /// Unterzeile unter „Artikel abhaken“.
    var hint: String {
        switch self {
        case .swipe: return "Nach rechts wischen – ohne Kreis auf der Karte"
        case .circle: return "Kreis auf der Karte antippen – Wischen nach rechts aus"
        case .both: return "Nach rechts wischen oder Kreis antippen"
        }
    }

    /// Kreis rechts auf der Artikelkarte sichtbar.
    var showsCircle: Bool { self != .swipe }
    /// Nach rechts wischen hakt ab (bzw. löscht Abgehakte).
    var allowsSwipe: Bool { self != .circle }

    /// Gespeicherter Wert → Auswahl (unbekannt → Standard).
    static func from(_ raw: String) -> CheckGesture { CheckGesture(rawValue: raw) ?? defaultValue }
}
