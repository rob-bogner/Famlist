/*
 RoundHeaderIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder 44er-Knopf der Top-Bar (Ansicht wechseln / Mehr).

 🔰 Notes for Beginners:
 - `RoundHeaderIcon` ist nur die Optik. So kann derselbe Look als Button oder als Menu-Label dienen.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Visual of the round 44 pt header button (usable as Button or Menu label).
struct RoundHeaderIcon: View {
    let t: ListTheme
    let icon: [SVGElement]

    var body: some View {
        SVGIcon(icon, size: 20, color: t.icon, lineWidth: 1.9)
            .frame(width: 44, height: 44)
            .background(CSSBox(shape: Circle(), paint: t.round, border: 1, borderColor: t.roundBorder, shadows: t.roundShadow))
            .contentShape(Circle())
    }
}

#Preview {
    HStack(spacing: 10) {
        RoundHeaderIcon(t: ListTheme(.light), icon: Icon.viewToggle)
        RoundHeaderIcon(t: ListTheme(.light), icon: Icon.menu)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: 10) {
        RoundHeaderIcon(t: ListTheme(.dark), icon: Icon.viewToggle)
        RoundHeaderIcon(t: ListTheme(.dark), icon: Icon.menu)
    }
    .padding()
    .background(Color.hex("#0A1416"))
}
