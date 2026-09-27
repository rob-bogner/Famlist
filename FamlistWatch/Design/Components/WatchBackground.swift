/*
 WatchBackground.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bildschirm-Hintergrund: radial-gradient(120% 70% at 50% 110%, rgba(accent,.16), rgba(0,0,0,0) 60%), #000.

 🔰 Notes for Beginners:
 - CSS-Ellipse: waagrechter Radius 120 % der Breite, senkrechter 70 % der Höhe, Mitte 50 % / 110 %
   (CSSRadialGradient aus dem iOS-Designsystem).
 - CSS mischt Verläufe mit vormultipliziertem Alpha; deshalb endet der Verlauf in der Akzentfarbe
   mit Deckkraft 0 statt in Schwarz-transparent (sonst würde die Mitte grau).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchBackground: View {
    var w = WatchTheme()

    var body: some View {
        ZStack {
            Color.black
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 1.1), extent: .ellipse(rx: 1.2, ry: 0.7),
                              stops: [stop(w.glow, 0), stop(w.accent.color(0), 0.6)])
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WatchBackground()
}
