/*
 InsightChip.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Chip im Hero der Auswertung („↑ 8 % ggü. August“, „9 Einkäufe“, „Ø 45,82 €“).

 🔰 Notes for Beginners:
 - Maße aus InsightSpend/InsightUsage: Padding 4/10, Radius 11, weiß 20 %, DM Sans 12/600, weiß.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InsightChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.dm(12, 600))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(RR(11).fill(Color.rgba(255, 255, 255, 0.2)))
    }
}

#Preview("Chip") {
    InsightChip(text: "↑ 8 % ggü. August").padding().background(Color.teal)
}

#Preview("Chip – Dark") {
    InsightChip(text: "9 Einkäufe").padding().background(Color.black)
}
