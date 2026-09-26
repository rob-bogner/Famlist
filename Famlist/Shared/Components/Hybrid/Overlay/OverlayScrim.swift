/*
 OverlayScrim.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abdunkelung eines Overlays: Hintergrund 2 pt weichgezeichnet + Farbschicht, Tippen schließt.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Scrim: `backdrop-filter: blur(2px)` auf den Hintergrund + Abdunkelung darüber.
struct OverlayScrim<Background: View>: View {
    let color: Color
    var blur: CGFloat = 2
    var onTap: () -> Void = {}
    @ViewBuilder let background: () -> Background

    var body: some View {
        ZStack {
            (background as () -> Background)()   // eindeutig: nicht View.background(ignoresSafeAreaEdges:)
                .blur(radius: blur, opaque: true)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            color
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .accessibilityHidden(true)
        }
    }
}

#Preview("OverlayScrim", traits: .fixedLayout(width: 390, height: 844)) {
    OverlayScrim(color: OverlayTheme(.light).scrim) {
        DesignListScreen(appearance: .light)
    }
    .ignoresSafeArea()
}

#Preview("OverlayScrim – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    OverlayScrim(color: OverlayTheme(.dark).scrim) {
        DesignListScreen(appearance: .dark)
    }
    .ignoresSafeArea()
}
