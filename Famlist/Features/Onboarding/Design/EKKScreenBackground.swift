/*
 EKKScreenBackground.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bildschirm-Hintergrund der Einstiegs-Screens (Light weiß, Dark #071012 mit Akzent-Schimmer).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Bildschirm-Hintergrund `bg`: Light #FFFFFF,
/// Dark `radial-gradient(120% 60% at 50% 100%, accent/.1, transparent 60%), #071012`.
struct EKKScreenBackground: View {
    let t: EKKTokens

    var body: some View {
        if t.isDark {
            ZStack {
                Color.hex("#071012")
                CSSRadialGradient(center: UnitPoint(x: 0.5, y: 1), extent: .ellipse(rx: 1.2, ry: 0.6),
                                  stops: [stop(t.a.base.color(0.1), 0), stop(t.a.base.color(0), 0.6)])
            }
        } else {
            Color.white
        }
    }
}

#Preview("EKKScreenBackground", traits: .fixedLayout(width: 390, height: 844)) {
    EKKScreenBackground(t: EKKTokens(.light))
}

#Preview("EKKScreenBackground – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    EKKScreenBackground(t: EKKTokens(.dark))
}
