/*
 ReceiptMetaGrid.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Raster 3 × 2 mit den Einkaufsdaten eines Bons (Board ReceiptDetailMeta), Abstand 8.

 🔰 Notes for Beginners:
 - Drei gleich breite Spalten wie `grid-template-columns: 1fr 1fr 1fr`; Kacheln einer Reihe gleich hoch.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptMetaGrid: View {
    let tiles: [ReceiptMetaTile]
    let t: ListAccountTokens

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: tiles.count, by: 3)), id: \.self) { start in
                GridRow {
                    ForEach(tiles[start..<min(start + 3, tiles.count)]) { tile in
                        ReceiptMetaTileView(tile: tile, t: t)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Einkaufsdaten", traits: .fixedLayout(width: 390, height: 200)) {
    ReceiptMetaGrid(tiles: ReceiptDetailFormat.tiles(ArchivedReceipt.designSamples[0],
                                                     lines: ArchivedReceipt.designSamples[0].lines),
                    t: ListAccountTokens(.light))
        .padding(20)
}

#Preview("Einkaufsdaten – Dark", traits: .fixedLayout(width: 390, height: 200)) {
    ReceiptMetaGrid(tiles: ReceiptDetailFormat.tiles(ArchivedReceipt.designSamples[0],
                                                     lines: ArchivedReceipt.designSamples[0].lines),
                    t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.black)
}
