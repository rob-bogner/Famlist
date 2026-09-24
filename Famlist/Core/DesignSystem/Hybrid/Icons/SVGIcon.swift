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

    init(_ elements: [SVGElement], size: CGFloat, color: Color, lineWidth: CGFloat) {
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
