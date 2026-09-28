/*
 ReceiptLineRow.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Artikelzeile im Bon-Detail (Board ReceiptDetailMeta): Kategorie-Kachel, Name, Menge und Einzelpreis,
   Kategorie in ihrer Farbe, rechts der Betrag.

 🔰 Notes for Beginners:
 - Maße aus dem Board: Padding 11/14, Abstand 12; Kachel 38 (Radius 12, Kategoriefarbe 12 % / Dunkel 18 %,
   Icon 19 mit Strich 1,9); Name 15/600, Menge 12 sub, Kategorie 12/600 farbig; Betrag Outfit 16/600.
 - Nur zugeordnete Zeilen sind tippbar (öffnen den Preisverlauf); die übrigen sind reiner Text.
 - Die Trennlinie zeichnet die Karte (ReceiptDetailSheet), nicht die Zeile.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptLineRow: View {
    let row: ReceiptLineDisplay
    let k: SheetTheme
    var onOpen: ((String) -> Void)? = nil

    var body: some View {
        if let itemName = row.itemName, let onOpen {
            Button(action: { onOpen(itemName) }) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet den Preisverlauf")
        } else {
            content
        }
    }

    private var content: some View {
        let color = InsightPalette.color(rank: row.rank, dark: k.isDark)
        return HStack(spacing: 12) {
            CategoryTile(category: row.category, rank: row.rank, size: 38, radius: 12, iconSize: 19, dark: k.isDark)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                Text(row.detail)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
                Text(row.categoryName)
                    .font(AppFont.dm(12, 600))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.amount)
                .font(AppFont.outfit(16, 600))
                .foregroundStyle(k.text)
                .fixedSize()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.detail), \(row.categoryName), \(row.amount)")
    }
}

#Preview("Artikelzeile", traits: .fixedLayout(width: 350, height: 80)) {
    ReceiptLineRow(row: ReceiptLineDisplay(id: 0, name: "Kerrygold Butter", detail: "1 × 250 g · je 2,49 €",
                                           categoryName: "Milchprodukte", category: CategoryDefinition.defaults[1],
                                           rank: 1, amount: "2,49 €", itemName: "Kerrygold Butter"),
                   k: SheetTheme(.light))
}

#Preview("Artikelzeile – Dark", traits: .fixedLayout(width: 350, height: 80)) {
    ReceiptLineRow(row: ReceiptLineDisplay(id: 0, name: "TUETE", detail: "1 Stück · je 0,20 €",
                                           categoryName: ReceiptLineDisplay.noCategory, category: nil,
                                           rank: nil, amount: "0,20 €", itemName: nil),
                   k: SheetTheme(.dark))
        .background(Color.black)
}
