/*
 UsageSparkline.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mini-Verlauf 64 × 28 der Menge über 6 Monate (Board InsightUsage), Linie in Kategoriefarbe, Punkt am Ende.

 🔰 Notes for Beginners:
 - Board: x-Schritt 12,8; kleinster Wert bei y 24, größter bei y 4; Linie 2 pt, runde Enden; Punkt Radius 3.
 - Sind alle Werte gleich, liegt die Linie in der Mitte (y 14; nicht gestaltet).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct UsageSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, _ in
            let points = Self.points(values)
            guard let last = points.last else { return }
            var path = Path()
            path.addLines(points)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(color))
        }
        .frame(width: 64, height: 28)
        .accessibilityHidden(true)
    }

    /// Punkte im 64 × 28-Feld des Boards.
    static func points(_ values: [Double]) -> [CGPoint] {
        guard let low = values.min(), let high = values.max() else { return [] }
        let step = values.count > 1 ? 64 / CGFloat(values.count - 1) : 0
        return values.enumerated().map { index, value in
            let y: CGFloat = high > low ? 24 - CGFloat((value - low) / (high - low)) * 20 : 14
            return CGPoint(x: CGFloat(index) * step, y: y)
        }
    }
}

#Preview("Verlauf") {
    UsageSparkline(values: [10, 11, 12, 11, 12, 14], color: .blue).padding()
}

#Preview("Verlauf – Dark") {
    UsageSparkline(values: [2, 2, 1, 2, 2, 2], color: .purple).padding().background(Color.black)
}
