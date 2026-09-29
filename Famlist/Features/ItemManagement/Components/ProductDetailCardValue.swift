/*
 ProductDetailCardValue.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Wert einer Karte in „Produktdetails“: DM Sans 16/600, einzeilig, optional Chevron rechts (14).

 🔰 Notes for Beginners:
 - Chevron nach unten = Auswahl (Bearbeiten), nach rechts = Link (Preisverlauf).

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Wert-Text einer Karte: DM Sans 16/600, einzeilig.
struct ProductDetailCardValue: View {
    let text: String
    let color: Color
    var trailing: [SVGElement]? = nil
    var trailingColor: Color = .clear

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(AppFont.dm(16, 600))
                .tracking(-0.16)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                SVGIcon(trailing, size: 14, color: trailingColor, lineWidth: 2.2)
            }
        }
    }
}
