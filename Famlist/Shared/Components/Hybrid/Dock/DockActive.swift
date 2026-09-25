/*
 DockActive.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Welcher Dock-Knopf gewählt ist bzw. welches Dock-Menü offen ist.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/Dock.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Welcher Knopf aktiv ist (bzw. welches Menü offen ist).
enum DockActive {
    case none      // Ruhezustand → „Alle abhaken“ ausgewählt
    case sort
    case copy
    case copied    // Pille zeigt „Kopiert“ mit Haken
    case delete    // rotes Highlight
}
