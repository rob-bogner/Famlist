/*
 ListAccountMenuItem.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Menüeintrag der Listen-Optionen: 48 hoch, Icon 20, Text 15/500.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Menüeintrag: 48 hoch, padding 0 12, Radius 16, Icon 20 (Strich 1,9, accentText), gap 12, Text 15/500.
struct ListAccountMenuItem: View {
    let t: ListAccountTokens
    let icon: [SVGElement]
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SVGIcon(icon, size: 20, color: t.accentText, lineWidth: 1.9)
                Text(title)
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(t.k.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 48)
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
    }
}

#Preview("ListAccountMenuItem") {
    ListAccountMenuItem(t: ListAccountTokens(.light), icon: ListAccountIcon.copy, title: "Duplizieren", action: {})
        .padding(20)
}

#Preview("ListAccountMenuItem – Dark") {
    ListAccountMenuItem(t: ListAccountTokens(.dark), icon: ListAccountIcon.copy, title: "Duplizieren", action: {})
        .padding(20)
        .background(Color.hex("#0A1416"))
}
