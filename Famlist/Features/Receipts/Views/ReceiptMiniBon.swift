/*
 ReceiptMiniBon.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mini-Bon 46 × 62 im Archiv (ReceiptArchive.dc.html): verkleinertes erstes Foto, bei mehreren Fotos
   ein Zähler rechts unten.

 🔰 Notes for Beginners:
 - Bis das Foto geladen ist (oder wenn es fehlt), zeigt die Fläche den gezeichneten Bon aus dem Design:
   Papier #F4F1EA, Radius 10, Padding 7/6, sechs Striche mit Abstand 4.
 - Zähler: min. 18 × 18, Pille, Padding 0 5, Hintergrund k.icon, Text k.sheetSolid 10/700,
   um 4 pt über die rechte untere Ecke hinaus.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptMiniBon: View {
    let k: SheetTheme
    var image: UIImage?
    var count = 1

    /// Striche des Platzhalters: (Höhe, Breite in %, Farbe)
    private static let strokes: [(CGFloat, CGFloat, String)] = [
        (3, 0.7, "#B9B4AA"), (2, 1, "#CFCAC0"), (2, 0.85, "#CFCAC0"),
        (2, 1, "#CFCAC0"), (2, 0.6, "#CFCAC0"), (2, 0.9, "#CFCAC0")
    ]

    var body: some View {
        paper
            .overlay(alignment: .bottomTrailing) {
                if count > 1 { badge.offset(x: 4, y: 4) }
            }
            .accessibilityHidden(true)
    }

    private var paper: some View {
        ZStack {
            Color.hex("#F4F1EA")
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 62)
            } else {
                placeholderLines
            }
        }
        .frame(width: 46, height: 62)
        .clipShape(RR(10))
        .background(CSSBox(shape: RR(10), paint: .color(.hex("#F4F1EA")),
                           shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6)),
                                     .drop(0, 4, 10, -4, .rgba(12, 40, 44, 0.35))]))
    }

    private var placeholderLines: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<Self.strokes.count, id: \.self) { i in
                    let s = Self.strokes[i]
                    RR(1).fill(Color.hex(s.2)).frame(width: geo.size.width * s.1, height: s.0)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
    }

    private var badge: some View {
        Text("\(count)")
            .font(AppFont.dm(10, 700))
            .foregroundStyle(k.isDark ? Color.hex("#0A1416") : Color.white)      // k.sheetSolid
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(k.icon))
            .fixedSize()
    }
}

#Preview {
    HStack(spacing: 20) {
        ReceiptMiniBon(k: SheetTheme(.light), count: 2)
        ReceiptMiniBon(k: SheetTheme(.light))
    }
    .padding(30)
}

#Preview("Dark") {
    HStack(spacing: 20) {
        ReceiptMiniBon(k: SheetTheme(.dark), count: 2)
        ReceiptMiniBon(k: SheetTheme(.dark))
    }
    .padding(30)
    .background(Color.hex("#0A1416"))
}
