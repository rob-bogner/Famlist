/*
 OverlayCapsLabel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Versal-Label der Overlays (600, letter-spacing .06em, Großbuchstaben).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Versal-Label: font-weight 600, letter-spacing .06em, text-transform uppercase.
struct OverlayCapsLabel: View {
    let text: String
    var size: CGFloat = 12
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.dm(size, 600))
            .tracking(size * 0.06)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}
