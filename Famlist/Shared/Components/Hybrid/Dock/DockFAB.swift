/*
 DockFAB.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Plus-Knopf (64 pt) rechts neben der Dock-Leiste.

 📝 Last Change:
 - Aus DockView.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - FAB 64

struct DockFAB: View {
    let t: ListTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SVGIcon(Icon.plus, size: 26, color: .white, lineWidth: 2.6)
                .shadow(color: .rgba(0, 40, 45, 0.35), radius: 1.5, x: 0, y: 2)   // drop-shadow(0 2px 3px)
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        // left/right 11, top 4, Höhe 24
                        GlossEllipse(opacity: 0.6)
                            .frame(height: 24)
                            .padding(.horizontal, 11)
                            .padding(.top, 4)
                            .frame(maxHeight: .infinity, alignment: .top)
                        // left/right 17, bottom 4, Höhe 8, filter: blur(3px)
                        Ellipse()
                            .fill(Color.rgba(255, 255, 255, 0.22))
                            .frame(height: 8)
                            .blur(radius: 3)
                            .padding(.horizontal, 17)
                            .padding(.bottom, 4)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(Circle())                                          // overflow: hidden
                .background(CSSBox(shape: Circle(), paint: t.fabBg, shadows: t.fabShadow))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Neuer Artikel")
    }
}

#Preview("Plus-Knopf") {
    DockFAB(t: ListTheme(.light), action: {})
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Plus-Knopf – Dark") {
    DockFAB(t: ListTheme(.dark), action: {})
        .padding(20)
        .background(Color.hex("#0A1416"))
}
