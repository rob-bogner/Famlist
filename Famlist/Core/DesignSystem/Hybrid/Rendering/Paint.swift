/*
 Paint.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hintergrund einer CSS-Box: Farbe, linear-gradient oder radial-gradient.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hintergrund einer CSS-Box.
enum Paint {
    case color(Color)
    /// `linear-gradient(<angle>deg, …)`
    case linear(Double, [Gradient.Stop])
    /// `radial-gradient(circle at x% y%, …)` – Größe `farthest-corner`
    case radialCircle(UnitPoint, [Gradient.Stop])

    @ViewBuilder var view: some View {
        switch self {
        case .color(let c):
            Rectangle().fill(c)
        case .linear(let angle, let stops):
            CSSLinearGradient(angle: angle, stops: stops)
        case .radialCircle(let center, let stops):
            CSSRadialGradient(center: center, extent: .circleFarthestCorner, stops: stops)
        }
    }
}
