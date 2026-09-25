/*
 EKKGlassBadge.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Glas-Kachel im Hero (Verlauf 160°, Rahmen weiß 45 %).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Glas-Kachel im Hero: `linear-gradient(160deg, weiß .4 → .14)`, Rahmen 1 weiß .45, inset 0 1 0 weiß .6.
struct EKKGlassBadge<S: InsettableShape>: View {
    let shape: S
    let size: CGFloat           // Außenmaß inkl. Rahmen (content-box + 2)

    var body: some View {
        CSSBox(shape: shape,
               paint: .linear(160, [stop(.rgba(255, 255, 255, 0.4), 0), stop(.rgba(255, 255, 255, 0.14), 1)]),
               border: 1, borderColor: .rgba(255, 255, 255, 0.45),
               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6))])
            .frame(width: size, height: size)
    }
}

#Preview("EKKGlassBadge") {
    EKKGlassBadge(shape: Circle(), size: 94)
        .frame(width: 94, height: 94)
        .padding(20)
        .background(SheetTheme(.light).accent)
}

#Preview("EKKGlassBadge – Dark") {
    EKKGlassBadge(shape: Circle(), size: 94)
        .frame(width: 94, height: 94)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
