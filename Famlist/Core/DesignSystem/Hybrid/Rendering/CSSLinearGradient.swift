/*
 CSSLinearGradient.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Exakte CSS-linear-gradient-Geometrie für beliebige Winkel.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Exakte CSS-`linear-gradient`-Geometrie für beliebige Winkel und Seitenverhältnisse.
/// CSS: 0deg = nach oben, im Uhrzeigersinn; Länge der Verlaufslinie = |w·sinθ| + |h·cosθ|.
struct CSSLinearGradient: View {
    let angle: Double
    let stops: [Gradient.Stop]

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 0.0001)
            let h = max(geo.size.height, 0.0001)
            let rad = angle * .pi / 180
            let dx = CGFloat(sin(rad))
            let dy = CGFloat(-cos(rad))
            let len = abs(w * CGFloat(sin(rad))) + abs(h * CGFloat(cos(rad)))
            let cx = w / 2
            let cy = h / 2
            LinearGradient(
                stops: stops,
                startPoint: UnitPoint(x: (cx - dx * len / 2) / w, y: (cy - dy * len / 2) / h),
                endPoint: UnitPoint(x: (cx + dx * len / 2) / w, y: (cy + dy * len / 2) / h)
            )
        }
    }
}
