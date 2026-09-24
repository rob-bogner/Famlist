/*
 PopoverMenuHeading.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Überschrift eines Dock-Menüs (12/600 Versalien).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Menü-Überschrift (Dock-Menüs): padding 10 12 6 12, 12/600 Versalien, Farbe sub.
struct PopoverMenuHeading: View {
    let text: String
    let k: OverlayTheme

    var body: some View {
        OverlayCapsLabel(text: text, size: 12, color: k.sub)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 6, trailing: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
