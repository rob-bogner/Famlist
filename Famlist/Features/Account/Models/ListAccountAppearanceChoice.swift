/*
 ListAccountAppearanceChoice.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Auswahl im Segment „Erscheinungsbild“ der Einstellungen: System / Hell / Dunkel.

 🔰 Notes for Beginners:
 - Gespeichert per @AppStorage("appearanceChoice"); RootView setzt daraus app-weit `preferredColorScheme`.
 - „System“ = nil → iOS entscheidet.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4). Werte aus AccountScreens.swift.
 ------------------------------------------------------------------------
 */

import SwiftUI

enum ListAccountAppearanceChoice: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Hell"
    case dark = "Dunkel"
    var id: String { rawValue }

    /// Schlüssel für @AppStorage.
    static let storageKey = "appearanceChoice"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
