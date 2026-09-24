/*
 PriceHistoryChart.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Preisdiagramm nach dem SVG des Designs (viewBox −6 −6 330 162, verzerrt wie preserveAspectRatio="none").

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ItemExtraScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Diagramm exakt nach dem SVG: viewBox −6 −6 330 162, preserveAspectRatio="none".
/// Konturen werden im viewBox-Raum erzeugt und erst dann verzerrt – wie im Browser
/// (Strichstärken skalieren mit x 316/330 bzw. y 160/162).
struct PriceHistoryChart: View {
    let line: Color
    let areaFill: Color
    let accent: Color
    let dotFill: Color

    /// Punkte in viewBox-Koordinaten (Mär … Sep)
    private static let points: [CGPoint] = [
        CGPoint(x: 0.0, y: 114.4), CGPoint(x: 53.0, y: 95.6), CGPoint(x: 106.0, y: 95.6),
        CGPoint(x: 159.0, y: 58.1), CGPoint(x: 212.0, y: 76.9), CGPoint(x: 265.0, y: 39.4),
        CGPoint(x: 318.0, y: 58.1)
    ]

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 330
            let sy = size.height / 162
            let tf = CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: 6 * sx, ty: 6 * sy)
            let pts = Self.points

            // Durchschnittslinie: M0 75 H318, 1 px, gestrichelt 4 4
            var avg = Path()
            avg.move(to: CGPoint(x: 0, y: 75))
            avg.addLine(to: CGPoint(x: 318, y: 75))
            ctx.fill(avg.strokedPath(StrokeStyle(lineWidth: 1, dash: [4, 4])).applying(tf), with: .color(line))

            // Fläche: Linie + L318 150 L0 150 Z
            var area = Path()
            area.move(to: pts[0])
            for p in pts.dropFirst() { area.addLine(to: p) }
            area.addLine(to: CGPoint(x: 318, y: 150))
            area.addLine(to: CGPoint(x: 0, y: 150))
            area.closeSubpath()
            ctx.fill(area.applying(tf), with: .color(areaFill))

            // Linie: 2,5, runde Enden/Ecken
            var polyline = Path()
            polyline.move(to: pts[0])
            for p in pts.dropFirst() { polyline.addLine(to: p) }
            ctx.fill(polyline.strokedPath(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)).applying(tf),
                     with: .color(accent))

            // Punkte: r 3,5 (Füllung dotFill), letzter r 5 (Füllung Akzent); Kontur jeweils 2 in Akzent
            for (i, p) in pts.enumerated() {
                let last = i == pts.count - 1
                let r: CGFloat = last ? 5 : 3.5
                let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(dot.applying(tf), with: .color(last ? accent : dotFill))
                ctx.fill(dot.strokedPath(StrokeStyle(lineWidth: 2)).applying(tf), with: .color(accent))
            }
        }
        .allowsHitTesting(false)
    }
}
