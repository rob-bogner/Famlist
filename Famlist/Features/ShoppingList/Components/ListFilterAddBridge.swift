/*
 ListFilterAddBridge.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Brücke vom Filter zum Hinzufügen (Canvas SearchInline): „„milch“ zur Liste hinzufügen“.

 🔰 Notes for Beginners:
 - 60 hoch, Radius 18, gestrichelter Rand 1,5 (Akzent .4 / .45), Text 15/600 Akzenttext,
   rechts Glas-Knopf „+“ 40 (Akzent). Öffnet die Eingabe unten mit dem Suchbegriff.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ListFilterAddBridge: View {
    let t: ListTheme
    let query: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("„\(query)“ zur Liste hinzufügen")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(t.accentText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GlassOrb(style: .accent, appearance: t.appearance, accent: t.a, icon: Icon.plus, size: 40, lineWidth: 2.4)
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .frame(height: 60)
            .contentShape(RR(18))
            .overlay(RR(18).strokeBorder(t.a.base.color(t.isDark ? 0.45 : 0.4),
                                         style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(query) zur Liste hinzufügen")
    }
}

#Preview("Brücke") {
    ListFilterAddBridge(t: ListTheme(.light), query: "milch") {}
        .padding(20)
}

#Preview("Brücke – Dark") {
    ListFilterAddBridge(t: ListTheme(.dark), query: "milch") {}
        .padding(20)
        .background(Color.hex("#071012"))
}
