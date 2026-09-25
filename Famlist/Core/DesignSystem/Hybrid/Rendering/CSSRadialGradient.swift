/*
 CSSRadialGradient.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Exakte CSS-radial-gradient-Geometrie (circle / closest-side / Prozent-Ellipse).

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Exakte CSS-`radial-gradient`-Geometrie.
struct CSSRadialGradient: View {
    enum Extent {
        /// `circle at …` (Standardgröße farthest-corner)
        case circleFarthestCorner
        /// `radial-gradient(closest-side, …)` – Ellipse bis zur nächsten Kante
        case ellipseClosestSide
        /// `radial-gradient(<rx%> <ry%> at …)` – Radien als Anteil von Breite/Höhe
        case ellipse(rx: CGFloat, ry: CGFloat)
    }

    let center: UnitPoint
    let extent: Extent
    let stops: [Gradient.Stop]

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width * center.x, y: size.height * center.y)
            var rx: CGFloat = 0
            var ry: CGFloat = 0
            switch extent {
            case .circleFarthestCorner:
                let corners = [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                               CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                let r = corners.map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 0
                rx = r
                ry = r
            case .ellipseClosestSide:
                rx = min(c.x, size.width - c.x)
                ry = min(c.y, size.height - c.y)
            case .ellipse(let fx, let fy):
                rx = fx * size.width
                ry = fy * size.height
            }
            guard rx > 0, ry > 0 else { return }
            ctx.translateBy(x: c.x, y: c.y)
            ctx.scaleBy(x: rx, y: ry)
            let rect = CGRect(x: -c.x / rx, y: -c.y / ry, width: size.width / rx, height: size.height / ry)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
        }
        .allowsHitTesting(false)
    }
}

#Preview("CSSRadialGradient") {
    CSSRadialGradient(center: UnitPoint(x: 0.3, y: 0.3), extent: .circleFarthestCorner,
                      stops: [stop(.hex("#0FA3AE"), 0), stop(.hex("#FFFFFF"), 1)])
        .frame(width: 240, height: 140)
        .padding(20)
}

#Preview("CSSRadialGradient – Dark") {
    CSSRadialGradient(center: UnitPoint(x: 0.3, y: 0.3), extent: .ellipse(rx: 0.6, ry: 0.8),
                      stops: [stop(.hex("#1FC2CC"), 0), stop(.hex("#0A1416"), 1)])
        .frame(width: 240, height: 140)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
