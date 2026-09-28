/*
 InsightSectionHeader.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Überschrift eines Abschnitts der Auswertung („LETZTE 6 MONATE“ · „Ø 385 €“).

 🔰 Notes for Beginners:
 - Board: Padding 0/4, links 13/600 groß geschrieben mit 0,04 em Laufweite in sub, rechts 12 sub, Grundlinie gemeinsam.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InsightSectionHeader: View {
    let title: String
    var trailing: String = ""
    let k: SheetTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(AppFont.dm(13, 600))
                .tracking(0.52)                      // 0.04em × 13
                .foregroundStyle(k.sub)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(trailing)
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
        }
        .padding(.horizontal, 4)
    }
}

#Preview("Abschnitt") {
    InsightSectionHeader(title: "Letzte 6 Monate", trailing: "Ø 385 €", k: SheetTheme(.light)).padding()
}

#Preview("Abschnitt – Dark") {
    InsightSectionHeader(title: "Nach Kategorie", k: SheetTheme(.dark)).padding().background(Color.black)
}
