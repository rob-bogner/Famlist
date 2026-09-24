/*
 PopoverMenuTrailing.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rechter Inhalt einer Menüzeile: nichts, Häkchen oder Text.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum PopoverMenuTrailing {
    /// nichts rechts
    case empty
    /// Häkchen 18, Strich 2.4, Akzent
    case check
    /// Zähler/Meta-Text 13 pt; `color == nil` → sub
    case text(String, weight: CGFloat = 600, color: Color? = nil)
}
