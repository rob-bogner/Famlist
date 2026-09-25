/*
 ListAccountIconCTA.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Primär-Button mit Icon (wie CTAButton, zusätzlich Icon 20).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Primär-Button mit Icon (wie `CTAButton`, zusätzlich Icon 20 · gap 10, Strich 2 in Button-Textfarbe).
struct ListAccountIconCTA: View {
    let k: SheetTheme
    let icon: [SVGElement]
    let title: String
    var action: () -> Void = {}
    /// App: statt einer Aktion das System-Teilen-Sheet öffnen (ShareLink), gleiche Optik.
    var shareURL: URL? = nil

    var body: some View {
        if let shareURL {
            ShareLink(item: shareURL) { content }
                .buttonStyle(.plain)
        } else {
            Button(action: action) { content }
                .buttonStyle(.plain)
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            SVGIcon(icon, size: 20, color: k.ctaText, lineWidth: 2)
            Text(title)
                .font(AppFont.dm(16, 600))
                .foregroundStyle(k.ctaText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(alignment: .top) {
            GlossEllipse(opacity: 0.45)
                .frame(height: 22)
                .padding(.horizontal, 24)
                .padding(.top, 2)
        }
        .clipShape(Pill)
        .background(CSSBox(shape: Pill, paint: k.ctaPaint, shadows: k.ctaShadow))
        .contentShape(Pill)
    }
}
