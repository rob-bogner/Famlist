/*
 ListAccountSectionLabel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abschnittsüberschrift 13/600 in Großbuchstaben (sub).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Abschnittsüberschrift: 13/600, letter-spacing .04em, Großbuchstaben, sub, padding 0 4.
struct ListAccountSectionLabel: View {
    let text: String
    let t: ListAccountTokens

    var body: some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .tracking(0.52)                          // 0.04em × 13
            .textCase(.uppercase)
            .foregroundStyle(t.k.sub)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("ListAccountSectionLabel") {
    ListAccountSectionLabel(text: "Mitglieder", t: ListAccountTokens(.light))
        .padding(20)
}

#Preview("ListAccountSectionLabel – Dark") {
    ListAccountSectionLabel(text: "Mitglieder", t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
