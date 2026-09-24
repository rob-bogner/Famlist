/*
 ListAccountFieldGroup.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Feld-Beschriftung 13/600 + 6 + Feld.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Feld-Beschriftung (13/600, sub, padding-left 4) + 6 + Feld.
struct ListAccountFieldGroup<Field: View>: View {
    let label: String
    let t: ListAccountTokens
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(t.k.sub)
                .padding(.leading, 4)
            field()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
