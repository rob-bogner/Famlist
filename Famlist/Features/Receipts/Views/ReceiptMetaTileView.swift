/*
 ReceiptMetaTileView.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Kachel der Einkaufsdaten (Board ReceiptDetailMeta): Beschriftung mit Icon, Wert, Unterzeile.

 🔰 Notes for Beginners:
 - Maße aus dem Board: Padding 10/12 (+1 pt Rahmen, im Board außen), Radius 16, field-Hintergrund mit fieldBorder, Abstand 3;
   Beschriftung 11/600 sub mit Icon 13 in accentText (Abstand 5), Wert 15/600, Unterzeile 11 sub.
 - Wert und Unterzeile einzeilig, zu lange Texte enden mit „…“.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptMetaTileView: View {
    let tile: ReceiptMetaTile
    let t: ListAccountTokens

    var body: some View {
        let k = t.k
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                SVGIcon(icon, size: 13, color: t.accentText, lineWidth: 2.2)
                Text(tile.label)
                    .font(AppFont.dm(11, 600))
                    .foregroundStyle(k.sub)
            }
            Text(tile.value)
                .font(AppFont.dm(15, 600))
                .foregroundStyle(k.text)
                .lineLimit(1)
                .truncationMode(.tail)
            if let sub = tile.sub {
                Text(sub)
                    .font(AppFont.dm(11, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)                 // 10 + 1 pt Rahmen (CSS content-box)
        .padding(.horizontal, 13)               // 12 + 1
        .frame(maxHeight: .infinity, alignment: .top)
        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([tile.label, tile.value, tile.sub].compactMap { $0 }.joined(separator: ", "))
    }

    private var icon: [SVGElement] {
        switch tile.kind {
        case .store: return ReceiptMetaIcon.store
        case .date: return ReceiptMetaIcon.calendar
        case .time: return ReceiptMetaIcon.clock
        case .duration: return ReceiptMetaIcon.stopwatch
        case .items: return ReceiptMetaIcon.bag
        case .value: return ReceiptMetaIcon.euro
        }
    }
}

#Preview("Kachel", traits: .fixedLayout(width: 120, height: 80)) {
    ReceiptMetaTileView(tile: ReceiptMetaTile(kind: .time, value: "17:42", sub: "bis 18:05"), t: ListAccountTokens(.light))
        .padding(4)
}

#Preview("Kachel – Dark", traits: .fixedLayout(width: 120, height: 80)) {
    ReceiptMetaTileView(tile: ReceiptMetaTile(kind: .store, value: "Edeka Center", sub: "Leopoldstr. 82"),
                        t: ListAccountTokens(.dark))
        .padding(4)
        .background(Color.black)
}
