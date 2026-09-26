/*
 CircleCloseButton.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Schließen-/Zurück-Button als neutraler Glas-Knopf (GlassOrb).

 🔰 Notes for Beginners:
 - Baustein der Hybrid-Sheets. Maße und Farben 1:1 aus dem Design (siehe Core/DesignSystem/Hybrid/README.md).

 📝 Last Change:
 - Optik: neutraler Glas-Knopf (Designsprache wie FAB).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CircleCloseButton: View {
    let k: SheetTheme
    let size: CGFloat
    let iconSize: CGFloat
    let lineWidth: CGFloat
    /// Standard ✕; „Zurück“ nutzt denselben Knopf mit Icon.chevronLeft.
    var icon: [SVGElement] = Icon.close
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            // Neutraler Glas-Knopf (Designsprache wie FAB, Canvas-Token gn).
            GlassOrb(style: .neutral, appearance: k.appearance, accent: k.a, icon: icon, size: size,
                     iconSize: iconSize, lineWidth: lineWidth)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("CircleCloseButton") {
    CircleCloseButton(k: SheetTheme(.light), size: 36, iconSize: 18, lineWidth: 2.2)
        .padding(20)
}

#Preview("CircleCloseButton – Dark") {
    CircleCloseButton(k: SheetTheme(.dark), size: 36, iconSize: 18, lineWidth: 2.2)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
