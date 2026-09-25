/*
 OverlayDockLayer.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dock über der Abdunkelung eines Overlays (350 × 64, links 20, unten 34).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Dock über der Abdunkelung: Höhe 64, links/rechts 20, unten 34 (bei 390 pt: 350 breit).
struct OverlayDockLayer: View {
    let appearance: Appearance
    var accentHex: String? = nil
    let active: DockActive
    var pill: DockPill = .open

    var body: some View {
        DockView(appearance: appearance, accentHex: accentHex, active: active, pill: pill)
            .frame(height: 64)
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
