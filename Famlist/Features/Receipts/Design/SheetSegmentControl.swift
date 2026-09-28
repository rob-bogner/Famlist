/*
 SheetSegmentControl.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Segment mit zwei oder mehr Reitern (Boards ReceiptDetailMeta „Artikel · Bon-Foto“ und
   InsightSpend/InsightUsage „Ausgaben · Verbrauch“).

 🔰 Notes for Beginners:
 - Maße aus dem Board: Höhe 40, Innenabstand 4, Radius 14, Hintergrund segBg, Abstand 4;
   Reiter Radius 10, DM Sans 14/600; aktiv segOn mit Schatten, sonst durchsichtig in sub.
 - VoiceOver: jeder Reiter ist ein Tab mit „ausgewählt“, wenn aktiv.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SheetSegmentControl: View {
    let titles: [String]
    @Binding var selection: Int
    let t: ListAccountTokens
    var accessibilityLabel = ""

    var body: some View {
        HStack(spacing: 4) {
            ForEach(titles.indices, id: \.self) { index in
                tab(index)
            }
        }
        .padding(4)
        .frame(height: 40)
        .background(RR(14).fill(t.segBg))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func tab(_ index: Int) -> some View {
        let isOn = index == selection
        return Button(action: { selection = index }) {
            Text(titles[index])
                .font(AppFont.dm(14, 600))
                .foregroundStyle(isOn ? t.segOnText : t.k.sub)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isOn {
                        CSSBox(shape: RR(10), paint: .color(t.segOn),
                               shadows: [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.1)),
                                         .drop(0, 4, 10, -6, .rgba(12, 40, 44, 0.3))])
                    }
                }
                .contentShape(RR(10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint("Reiter \(index + 1) von \(titles.count)")
    }
}

#Preview("Segment") {
    SheetSegmentControl(titles: ["Artikel", "Bon-Foto"], selection: .constant(0), t: ListAccountTokens(.light))
        .padding(20)
}

#Preview("Segment – Dark") {
    SheetSegmentControl(titles: ["Ausgaben", "Verbrauch"], selection: .constant(1), t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.black)
}
