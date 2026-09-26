/*
 PillGlassReflection.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Weiche Glas-Spiegelung für breite Pillen-Buttons (CTA, „Prüfen“):
   abgerundeter Glanzstreifen oben + weicher Lichtsaum unten – wie Dock und FAB.

 🔰 Notes for Beginners:
 - Ersetzt die spitz auslaufende `GlossEllipse` auf breiten Buttons.
 - Canvas-Werte (1 CSS-px = 1 pt, filter: blur(X) → .blur(radius: X)):
   oben:  left/right 16 · top 3 · height 22 · radius 11 · Verlauf 0.45 → 0 · blur 1
   unten: left/right 40 · bottom 3 · height 8 · radius 4 · weiß 0.16 · blur 3

 📝 Last Change:
 - Initial creation (breite Buttons an Dock-Glaseffekt angeglichen).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Glas-Spiegelung einer Pille. Als `.background` VOR `.clipShape(Pill)` anhängen.
struct PillGlassReflection: View {
    var topInset: CGFloat = 16
    var topOffset: CGFloat = 3
    var topHeight: CGFloat = 22
    var topOpacity: Double = 0.45
    var glowInset: CGFloat = 40
    var glowOffset: CGFloat = 3
    var glowHeight: CGFloat = 8
    var glowOpacity: Double = 0.16
    var glowBlur: CGFloat = 3

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: topHeight / 2, style: .circular)
                .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, topOpacity), 0),
                                             stop(.rgba(255, 255, 255, 0), 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: topHeight)
                .blur(radius: 1)
                .padding(.horizontal, topInset)
                .padding(.top, topOffset)
                .frame(maxHeight: .infinity, alignment: .top)
            RoundedRectangle(cornerRadius: glowHeight / 2, style: .circular)
                .fill(Color.rgba(255, 255, 255, glowOpacity))
                .frame(height: glowHeight)
                .blur(radius: glowBlur)
                .padding(.horizontal, glowInset)
                .padding(.bottom, glowOffset)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("PillGlassReflection") {
    Color.clear
        .frame(height: 56)
        .background { PillGlassReflection() }
        .clipShape(Pill)
        .background(Pill.fill(Color.hex("#0FA3AE")))
        .padding(20)
}

#Preview("PillGlassReflection – Dark") {
    Color.clear
        .frame(height: 56)
        .background { PillGlassReflection() }
        .clipShape(Pill)
        .background(Pill.fill(Color.hex("#57BFC6")))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
