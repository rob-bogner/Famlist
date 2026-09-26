/*
 WatchGlassButton.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Glas-Knopf 42 pt: linear-gradient(180deg, weiß .2, weiß .1), Rand 1 px weiß .16,
   Icon 20 pt weiß (Strich 2,2). Im Design „Alle abhaken“ unten links.

 🔰 Notes for Beginners:
 - backdrop-filter: blur(16px) aus dem Design ist nicht übernommen: Unter dem Knopf liegt immer der
   Verlauf zu Schwarz .85, der Unterschied ist nicht sichtbar (PLAN.md §9).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchGlassButton: View {
    var w = WatchTheme()
    let icon: [SVGElement]
    var iconLineWidth: CGFloat = 2.2
    let label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            SVGIcon(icon, size: 20, color: .white, lineWidth: iconLineWidth)
                .frame(width: 42, height: 42)
                .background(CSSBox(shape: Circle(), paint: w.glassButton, border: 1, borderColor: w.glassBorder))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    WatchGlassButton(icon: WatchIcon.checkAll, label: "Alle abhaken")
        .padding()
        .background(Color.black)
}
