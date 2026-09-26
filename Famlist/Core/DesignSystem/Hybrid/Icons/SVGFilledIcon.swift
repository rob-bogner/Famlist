/*
 SVGFilledIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gefülltes Icon mit gleichfarbiger Kontur (`fill=c stroke=c stroke-linejoin=round`), z. B. Favoriten-Stern.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Gegenstück zu SVGIcon (nur Kontur).
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI 2 (Screen „Meine Listen“) übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Ein gefülltes Icon wie `<svg viewBox="0 0 24 24" fill=color stroke=color stroke-width=lineWidth>`.
struct SVGFilledIcon: View {
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
        ZStack {
            SVGIconShape(elements: elements).fill(color)
            SVGIconShape(elements: elements)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .butt, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    SVGFilledIcon(Icon.star, size: 48, color: .hex("#F5B521"), lineWidth: 1.5)
}

#Preview("SVGFilledIcon – Dark") {
    SVGFilledIcon(Icon.star, size: 48, color: .hex("#F5B521"), lineWidth: 1.5)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
