/*
 ReceiptPriceChangeRows.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt der Aktionskarte „Artikelpreise aktualisieren?“ (Canvas: ReceiptPriceAlert): je Artikel
   „alter Preis (durchgestrichen) → neuer Preis“.

 🔰 Notes for Beginners:
 - Karte field-Fläche, Rand, Radius 20; Zeilen Padding 11 / 14, Name 15/600, alter Preis 13 durchgestrichen,
   Pfeil 14, neuer Preis Outfit 16/600 – teurer in Warnfarbe, günstiger grün.
 - Höchstens 5 Zeilen, danach „und n weitere“.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Old → new price rows inside the "update prices" action card.
struct ReceiptPriceChangeRows: View {
    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let oldPrice: Double?
        let newPrice: Double
    }

    let k: SheetTheme
    let rows: [Row]

    var body: some View {
        let d = ActionCardTokens(k)
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                ForEach(Array(rows.prefix(5).enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Rectangle().fill(d.line).frame(height: 1) }
                    line(row, d: d)
                }
            }
            .background(CSSBox(shape: RR(20), paint: .color(d.field), border: 1, borderColor: d.fieldBorder))
            if rows.count > 5 {
                Text("und \(rows.count - 5) weitere")
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(d.sub)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func line(_ row: Row, d: ActionCardTokens) -> some View {
        let rising = (row.oldPrice ?? row.newPrice) < row.newPrice
        return HStack(spacing: 10) {
            Text(row.name)
                .font(AppFont.dm(15, 600))
                .foregroundStyle(d.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let old = row.oldPrice {
                Text(PriceDisplaySetting.euro(old))
                    .font(AppFont.dm(13, 400))
                    .strikethrough()
                    .foregroundStyle(d.strike)
                SVGIcon(Icon.arrowRight, size: 14, color: d.sub, lineWidth: 2)
                    .accessibilityHidden(true)
            }
            Text(PriceDisplaySetting.euro(row.newPrice))
                .font(AppFont.outfit(16, 600))
                .foregroundStyle(rising ? d.warn : d.ok)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.oldPrice.map { "\(row.name): \(PriceDisplaySetting.euro($0)) wird \(PriceDisplaySetting.euro(row.newPrice))" }
                            ?? "\(row.name): \(PriceDisplaySetting.euro(row.newPrice))")
    }
}

#Preview {
    ReceiptPriceChangeRows(k: SheetTheme(.light), rows: [.init(name: "Butter", oldPrice: 2.19, newPrice: 2.49),
                                                          .init(name: "Soyamilch", oldPrice: 2.49, newPrice: 2.29)])
        .padding(20)
}

#Preview("Dark") {
    ReceiptPriceChangeRows(k: SheetTheme(.dark), rows: [.init(name: "Butter", oldPrice: 2.19, newPrice: 2.49),
                                                         .init(name: "Soyamilch", oldPrice: 2.49, newPrice: 2.29)])
        .padding(20)
        .background(Color.black)
}
