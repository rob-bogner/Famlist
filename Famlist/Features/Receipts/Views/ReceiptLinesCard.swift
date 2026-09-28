/*
 ReceiptLinesCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte mit allen Artikelzeilen eines Bons (Board ReceiptDetailMeta), Trennlinie k.line zwischen den Zeilen.

 🔰 Notes for Beginners:
 - Karte: Radius 20, card-Hintergrund, 1 pt cardBorder, cardShadow (Werte aus ListAccountTokens).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptLinesCard: View {
    let rows: [ReceiptLineDisplay]
    let t: ListAccountTokens
    var onOpen: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                if row.id != rows.first?.id {
                    Rectangle().fill(t.line).frame(height: 1)
                }
                ReceiptLineRow(row: row, k: t.k, onOpen: onOpen)
            }
        }
        .padding(1)                                   // 1 pt Rahmen (CSS content-box)
        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    }
}

#Preview("Artikel", traits: .fixedLayout(width: 390, height: 500)) {
    ReceiptLinesCard(rows: ReceiptDetailFormat.rows(ArchivedReceipt.designSamples[0].lines ?? [], context: .designSample),
                     t: ListAccountTokens(.light))
        .padding(20)
}

#Preview("Artikel – Dark", traits: .fixedLayout(width: 390, height: 500)) {
    ReceiptLinesCard(rows: ReceiptDetailFormat.rows(ArchivedReceipt.designSamples[0].lines ?? [], context: .designSample),
                     t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.black)
}
