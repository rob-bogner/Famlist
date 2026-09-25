/*
 CircleCloseButton.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Schließen-Button (Kreis 44, Kreuz 18).

 🔰 Notes for Beginners:
 - Baustein der Hybrid-Sheets. Maße und Farben 1:1 aus dem Design (siehe Core/DesignSystem/Hybrid/README.md).

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CircleCloseButton: View {
    let k: SheetTheme
    let size: CGFloat
    let iconSize: CGFloat
    let lineWidth: CGFloat
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            SVGIcon(Icon.close, size: iconSize, color: k.icon, lineWidth: lineWidth)
                .frame(width: size, height: size)
                .background(Circle().fill(k.close))
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
