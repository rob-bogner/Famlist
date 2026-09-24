/*
 TopBorderHairline.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - CSS border-top auf einer Fläche mit oberen Radien (Dark-Sheet-Oberkante).

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// CSS `border-top: 1px solid c` auf einer Fläche mit oberen Radien:
/// die Linie läuft oben voll und verjüngt sich in den Ecken bis zur Höhe des Radius auf 0.
struct TopBorderHairline: View {
    let radius: CGFloat
    let color: Color

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .circular)
            .strokeBorder(color, lineWidth: 1)
            .mask(alignment: .top) {
                LinearGradient(stops: [stop(.black, 0), stop(.black.opacity(0), 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: radius)
            }
            .allowsHitTesting(false)
    }
}
