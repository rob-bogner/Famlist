/*
 PopoverMenuDivider.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Trennlinie im Popover-Menü (1 pt, Rand 4 / 10).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Trennlinie: height 1, margin 4px 10px → belegt 9 pt Höhe.
struct PopoverMenuDivider: View {
    let k: OverlayTheme

    var body: some View {
        Rectangle()
            .fill(k.line)
            .frame(height: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }
}
