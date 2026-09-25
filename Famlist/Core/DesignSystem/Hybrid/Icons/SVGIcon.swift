/*
 SVGIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kontur-Icon wie <svg stroke=… stroke-width=…>, Strichstärke skaliert mit der Größe.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Ein Kontur-Icon wie `<svg width=size height=size viewBox="0 0 24 24" stroke=color stroke-width=lineWidth>`.
struct SVGIcon: View {
    let elements: [SVGElement]
    let size: CGFloat
    let color: Color
    let lineWidth: CGFloat

    // nonisolated: Das init speichert nur Werte (kein Main-Actor-Zustand); so darf das Icon auch in
    // nicht isolierten Label-Closures stehen (z. B. PhotosPicker).
    nonisolated init(_ elements: [SVGElement], size: CGFloat, color: Color, lineWidth: CGFloat) {
        self.elements = elements
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        SVGIconShape(elements: elements)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

#Preview("SVGIcon") {
    SVGIcon(Icon.chevronDown, size: 48, color: .hex("#0FA3AE"), lineWidth: 2)
        .padding(20)
}

#Preview("SVGIcon – Dark") {
    SVGIcon(Icon.chevronDown, size: 48, color: .hex("#1FC2CC"), lineWidth: 2)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
