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

 - Echte Werte (Phase 7): Monatswerte und Durchschnitt werden auf die Design-Achse abgebildet:
   x = i · 53, y = 114,4 − (v − min) / (max − min) · 75. Monate ohne Preis (nil) bekommen keinen Punkt;
   die Linie verbindet nur vorhandene Werte. Sind alle Werte gleich, liegen sie auf halber Höhe.

 📝 Last Change:
 - Parameter `values` und `average` statt fester Beispielpunkte (Redesign „Hybrid“, Phase 7).
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
    /// Ein Wert pro Monat (älteste zuerst); nil = kein Preis in diesem Monat.
    var values: [Double?] = PriceHistoryChart.designValues
    /// Durchschnitt aller Preise (gestrichelte Linie); nil = keine Linie.
    var average: Double? = PriceHistoryChart.designAverage

    /// Werte aus PriceHistory.dc.html (Mär … Sep) für Vorschauen.
    static let designValues: [Double?] = [2.19, 2.29, 2.29, 2.49, 2.39, 2.59, 2.49]
    static let designAverage: Double? = 2.39

    /// Achse des Designs: niedrigster Wert auf y 114,4, höchster auf y 39,4, Abstand x 53.
    static let bottomY: CGFloat = 114.4
    static let span: CGFloat = 75
    static let stepX: CGFloat = 53

    /// Punkte in viewBox-Koordinaten; Monate ohne Wert fehlen.
    static func points(for values: [Double?]) -> [CGPoint] {
        let present = values.compactMap { $0 }
        guard let lo = present.min(), let hi = present.max() else { return [] }
        return values.enumerated().compactMap { i, v in
            v.map { CGPoint(x: CGFloat(i) * stepX, y: y(for: $0, lo: lo, hi: hi)) }
        }
    }

    /// y eines Werts; gleiche Werte → halbe Höhe. Auf die Zeichenfläche (0 … 150) begrenzt.
    static func y(for value: Double, lo: Double, hi: Double) -> CGFloat {
        let fraction = hi > lo ? (value - lo) / (hi - lo) : 0.5
        return min(150, max(0, bottomY - CGFloat(fraction) * span))
    }

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 330
            let sy = size.height / 162
            let tf = CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: 6 * sx, ty: 6 * sy)
            let pts = Self.points(for: values)
            guard let first = pts.first, let last = pts.last else { return }

            // Durchschnittslinie: M0 y H318, 1 px, gestrichelt 4 4
            let present = values.compactMap { $0 }
            if let average, let lo = present.min(), let hi = present.max() {
                let y = Self.y(for: average, lo: lo, hi: hi)
                var avg = Path()
                avg.move(to: CGPoint(x: 0, y: y))
                avg.addLine(to: CGPoint(x: 318, y: y))
                ctx.fill(avg.strokedPath(StrokeStyle(lineWidth: 1, dash: [4, 4])).applying(tf), with: .color(line))
            }

            if pts.count > 1 {
                // Fläche: Linie + L last.x 150 L first.x 150 Z
                var area = Path()
                area.move(to: first)
                for p in pts.dropFirst() { area.addLine(to: p) }
                area.addLine(to: CGPoint(x: last.x, y: 150))
                area.addLine(to: CGPoint(x: first.x, y: 150))
                area.closeSubpath()
                ctx.fill(area.applying(tf), with: .color(areaFill))

                // Linie: 2,5, runde Enden/Ecken
                var polyline = Path()
                polyline.move(to: first)
                for p in pts.dropFirst() { polyline.addLine(to: p) }
                ctx.fill(polyline.strokedPath(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)).applying(tf),
                         with: .color(accent))
            }

            // Punkte: r 3,5 (Füllung dotFill), letzter r 5 (Füllung Akzent); Kontur jeweils 2 in Akzent
            for (i, p) in pts.enumerated() {
                let isLast = i == pts.count - 1
                let r: CGFloat = isLast ? 5 : 3.5
                let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(dot.applying(tf), with: .color(isLast ? accent : dotFill))
                ctx.fill(dot.strokedPath(StrokeStyle(lineWidth: 2)).applying(tf), with: .color(accent))
            }
        }
        .allowsHitTesting(false)
    }
}
