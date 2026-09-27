/*
 WatchCardBackground.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karten-Fläche: linear-gradient(180deg, weiß .14, weiß .08), Rand 1 px weiß .08,
   optional inset 0 1px 0 weiß .12 (Artikel-, Listen-, Smart-Stack-Karten; nicht Stepper und Eingabe).

 🔰 Notes for Beginners:
 - Gezeichnet mit CSSBox aus dem iOS-Designsystem (CSS-Malreihenfolge, Rand innen, border-box).
 - CSS border-radius zeichnet Kreisbögen → RR() (.circular).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchCardBackground: View {
    var w = WatchTheme()
    var radius: CGFloat = 18
    var innerHighlight = true

    var body: some View {
        CSSBox(shape: RR(radius), paint: w.card, border: 1, borderColor: w.cardBorder,
               shadows: innerHighlight ? [w.cardShadow] : [])
    }
}

#Preview {
    WatchCardBackground()
        .frame(width: 184, height: 46)
        .padding()
        .background(Color.black)
}
