/*
 ListAccountDesignCaret.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Statischer Design-Cursor (nur Vorschau).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Statischer Design-Cursor: 2 × 22, Radius 1, Akzent.
struct ListAccountDesignCaret: View {
    let t: ListAccountTokens

    var body: some View {
        RR(1)
            .fill(t.k.accent)
            .frame(width: 2, height: 22)
            .accessibilityHidden(true)
    }
}

#Preview("ListAccountDesignCaret") {
    ListAccountDesignCaret(t: ListAccountTokens(.light))
        .padding(20)
}

#Preview("ListAccountDesignCaret – Dark") {
    ListAccountDesignCaret(t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
