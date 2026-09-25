/*
 ReceiptPageThumbnail.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vorschaubild einer Kassenzettel-Aufnahme in der Mini-Ansicht von „Kassenzettel fotografieren“.

 🔰 Notes for Beginners:
 - ReceiptCapture.dc.html: 46 × 62, Radius 10, Rahmen 2 (neueste Aufnahme weiß, sonst weiß 35 %),
   Nummer unten links (16 hoch, schwarz 60 %), ✕ 22 rund oben rechts (−8/−8).
 - Das ✕ ist nur 22 pt groß, die Tippfläche aber 44 × 44 pt (gleicher Mittelpunkt).

 📝 Last Change:
 - Initial creation (Redesign Kassenzettel fotografieren).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Mini-Vorschau einer Aufnahme mit Nummer und Lösch-Knopf.
struct ReceiptPageThumbnail: View {
    let image: UIImage
    let number: Int
    var isLatest = false
    var onDelete: () -> Void = {}

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 46, height: 62)
            .clipShape(RR(10))
            .overlay(RR(10).strokeBorder(isLatest ? Color.white : Color.rgba(255, 255, 255, 0.35), lineWidth: 2))
            .background(CSSBox(shape: RR(10), paint: .color(.hex("#F4F1EA")),
                               shadows: [.drop(0, 6, 14, -6, .rgba(0, 0, 0, 0.7))]))
            .overlay(alignment: .bottomLeading) {
                Text("\(number)")
                    .font(AppFont.dm(10, 700))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Capsule().fill(Color.rgba(0, 0, 0, 0.6)))
                    .padding(4)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) { deleteButton }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Aufnahme \(number)")
    }

    /// ✕ 22 rund bei right/top −8; Mitte (43 | 3) → 44er-Tippfläche um (+19 | −19) verschoben.
    private var deleteButton: some View {
        Button(action: onDelete) {
            SVGIcon(Icon.close, size: 10, color: .white, lineWidth: 3)
                .frame(width: 22, height: 22)
                .background(CSSBox(shape: Circle(), paint: .color(.rgba(20, 30, 32, 0.9)), border: 1,
                                   borderColor: .rgba(255, 255, 255, 0.3)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 19, y: -19)
        .accessibilityLabel("Aufnahme \(number) löschen")
    }
}

#Preview("Aufnahmen", traits: .fixedLayout(width: 200, height: 120)) {
    HStack(spacing: 10) {
        ReceiptPageThumbnail(image: UIImage(), number: 1)
        ReceiptPageThumbnail(image: UIImage(), number: 2, isLatest: true)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hex("#121A1B"))
}

#Preview("Aufnahmen – Dark", traits: .fixedLayout(width: 200, height: 120)) {
    ReceiptPageThumbnail(image: UIImage(), number: 1, isLatest: true)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hex("#0A1416"))
        .preferredColorScheme(.dark)
}
