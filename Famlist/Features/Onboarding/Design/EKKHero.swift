/*
 EKKHero.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hero-Fläche mit Verlauf, Glanz-Ellipse und zwei Zierringen (untere Radien 40).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hero-Fläche (volle Breite, untere Radien 40) mit Glanz-Ellipse und zwei Zierringen.
/// Die Ringe sind `div`s ohne box-sizing → Außenmaß 240 + 2 = 242 bzw. 130 + 2 = 132.
struct EKKHero<Content: View>: View {
    let t: EKKTokens
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40, style: .circular)
    }

    var body: some View {
        ZStack {
            t.heroBg.view
            // left −70, top −120, 340 × 260, radial-gradient(closest-side, weiß .42 → 0)
            CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                              stops: [stop(.rgba(255, 255, 255, 0.42), 0), stop(.rgba(255, 255, 255, 0), 1)])
                .clipShape(Ellipse())
                .frame(width: 340, height: 260)
                .offset(x: -70, y: -120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // right −70, top 60, Rahmen 1 rgba(255,255,255,.14)
            Circle()
                .strokeBorder(Color.rgba(255, 255, 255, 0.14), lineWidth: 1)
                .frame(width: 242, height: 242)
                .offset(x: 70, y: 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // right −10, top 120, Rahmen 1 rgba(255,255,255,.12)
            Circle()
                .strokeBorder(Color.rgba(255, 255, 255, 0.12), lineWidth: 1)
                .frame(width: 132, height: 132)
                .offset(x: 10, y: 120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(shape)
    }
}
