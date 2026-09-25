/*
 ListEmptyState.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Leer-Zustand der Liste: Korb-Kachel 72, „Die Liste ist leer“, Hinweis auf Suche und Plus.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListScreen.swift (ListEmptyState, Hybrid.dc.html state „empty“; steht 44 pt unter den Tabs).
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI


/// Korb ohne Streben (nur Henkel) – Pfade aus dem Leer-Zustand in Hybrid.dc.html.
private let listEmptyBasket: [SVGElement] = [
    .path("M3 10h18l-1.6 8.2a2 2 0 0 1-2 1.8H6.6a2 2 0 0 1-2-1.8L3 10z"),
    .path("M8 10l3-6M16 10l-3-6")
]

struct ListEmptyState: View {
    let t: ListTheme

    var body: some View {
        VStack(spacing: 12) {
            // 72 × 72, Radius 24, Icon 30 / Strich 1.8
            SVGIcon(listEmptyBasket, size: 30, color: t.thumbIcon, lineWidth: 1.8)
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

#Preview("Leer") { ListEmptyState(t: ListTheme(.light)).padding(20) }
#Preview("Leer – Dark") { ListEmptyState(t: ListTheme(.dark)).padding(20).background(Color.hex("#071012")) }
