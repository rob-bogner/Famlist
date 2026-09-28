/*
 SheetFadeScrollArea.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Scrollender Inhalt bis zum unteren Sheet-Rand mit weichem Auslauf (Boards ReceiptDetailMeta, InsightSpend,
   InsightUsage).

 🔰 Notes for Beginners:
 - Board: `margin: 0 -20px -34px -20px` (reicht über das Sheet-Padding hinaus), Innenabstand 0/20/40,
   Auslauf 70 hoch von durchsichtig zu `sheetSolid` (#FFFFFF hell, #0A1416 dunkel).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SheetFadeScrollArea<Content: View>: View {
    let t: ListAccountTokens
    /// Zusätzlicher Platz unten, z. B. für die Tastatur (Suchfeld im Reiter „Verbrauch“).
    var extraBottom: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40 + extraBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            LinearGradient(colors: [solid.opacity(0), solid], startPoint: .top, endPoint: .bottom)
                .frame(height: 70)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, -20)
        .padding(.bottom, -34)
    }

    /// `k.sheetSolid` im Board.
    private var solid: Color { t.isDark ? .hex("#0A1416") : .white }
}

#Preview("Scroll-Fläche", traits: .fixedLayout(width: 390, height: 400)) {
    SheetFadeScrollArea(t: ListAccountTokens(.light)) {
        VStack(spacing: 8) { ForEach(0..<20) { Text("Zeile \($0)").frame(maxWidth: .infinity) } }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 34)
}

#Preview("Scroll-Fläche – Dark", traits: .fixedLayout(width: 390, height: 400)) {
    SheetFadeScrollArea(t: ListAccountTokens(.dark)) {
        VStack(spacing: 8) { ForEach(0..<20) { Text("Zeile \($0)").foregroundStyle(.white).frame(maxWidth: .infinity) } }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 34)
    .background(Color.black)
}
