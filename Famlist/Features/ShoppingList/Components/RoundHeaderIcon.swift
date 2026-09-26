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
 - Optik jetzt neutraler Glas-Knopf (GlassOrb) wie im Canvas.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Visual of the round 44 pt header button (usable as Button or Menu label).
struct RoundHeaderIcon: View {
    let t: ListTheme
    let icon: [SVGElement]
    var lineWidth: CGFloat = 1.9

    /// Neutraler Glas-Knopf 44 (Canvas Hybrid: ☰ und Suche im Listenkopf).
    var body: some View {
        GlassOrb(style: .neutral, appearance: t.appearance, accent: t.a, icon: icon, size: 44,
                 iconSize: 20, lineWidth: lineWidth)
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
