/*
 GlossEllipse.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Glanz-Ellipse (weißer Verlauf nach transparent) auf Buttons.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Glanz-Ellipse: `border-radius: 50%; background: linear-gradient(180deg, rgba(255,255,255,a), rgba(255,255,255,0))`.
struct GlossEllipse: View {
    let opacity: Double

    var body: some View {
        Ellipse()
            .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, opacity), 0), stop(.rgba(255, 255, 255, 0), 1)],
                                 startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
    }
}
