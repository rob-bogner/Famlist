/*
 DesignListEmptyState.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Leer-Zustand der statischen Design-Liste für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Leer-Zustand

/// Korb ohne Streben (nur Henkel) – Pfade aus dem Leer-Zustand in Hybrid.dc.html.
private let DesignlistEmptyBasket: [SVGElement] = [
    .path("M3 10h18l-1.6 8.2a2 2 0 0 1-2 1.8H6.6a2 2 0 0 1-2-1.8L3 10z"),
    .path("M8 10l3-6M16 10l-3-6")
]

struct DesignListEmptyState: View {
    let t: ListTheme

    var body: some View {
        VStack(spacing: 12) {
            // 72 × 72, Radius 24, Icon 30 / Strich 1.8
            SVGIcon(DesignlistEmptyBasket, size: 30, color: t.thumbIcon, lineWidth: 1.8)
                .frame(width: 72, height: 72)
                .background(CSSBox(shape: RR(24), paint: t.thumb, shadows: t.thumbShadow))
                .accessibilityHidden(true)

            Text("Die Liste ist leer")
                .font(AppFont.outfit(19, 600))
                .foregroundStyle(t.text)

            // max-width 250, 14 px, line-height 1.45 (= 20,3), zentriert
            Text("Füge Artikel über die Suche oder das Plus hinzu.")
                .font(AppFont.dm(14, 400))
                .foregroundStyle(t.sub)
                .multilineTextAlignment(.center)
                .cssLineHeight(20.3, font: AppFont.ui(.dmSans, 14, 400))
                .frame(maxWidth: 250)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Leere Liste") {
    DesignListEmptyState(t: ListTheme(.light))
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Leere Liste – Dark") {
    DesignListEmptyState(t: ListTheme(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
