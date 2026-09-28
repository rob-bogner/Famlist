/*
 UsageProductRow.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeile „Am meisten gekauft“ (Board InsightUsage): Kategorie-Kachel, Name, Kosten, Mini-Verlauf, Menge und
   Veränderung zum Vormonat.

 🔰 Notes for Beginners:
 - Board: Padding 10/14, Abstand 12; Kachel 36 (Radius 12, Icon 18); Name 15/600, Kosten 12 sub (Abstand 2);
   rechts Spalte 70 breit: Menge Outfit 16/600, darunter Veränderung 11/600 sub mit Pfeil 14 (Abstand 3).
 - Veränderung ohne Wertung durch Farbe (immer sub); bei „±0“ ohne Pfeil.
 - Tippen öffnet den Preisverlauf des Produkts.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct UsageProductRow: View {
    let product: UsageInsights.Product
    let month: Date
    let context: ReceiptLineContext
    let k: SheetTheme
    var onOpen: ((String) -> Void)? = nil

    var body: some View {
        Button(action: { onOpen?(product.name) }) {
            HStack(spacing: 12) {
                CategoryTile(category: context.definition(named: product.category), rank: product.rank, size: 36,
                             radius: 12, iconSize: 18, dark: k.isDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(1)
                    Text(InsightFormat.euro(product.cost))
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                UsageSparkline(values: product.history, color: InsightPalette.color(rank: product.rank, dark: k.isDark))
                amountColumn
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onOpen == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(UsageInsightsText.accessibility(product, month: month))
        .accessibilityHint("Öffnet den Preisverlauf")
        .accessibilityAddTraits(.isButton)
    }

    private var amountColumn: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(UsageInsightsText.amount(product.amount))
                .font(AppFont.outfit(16, 600))
                .foregroundStyle(k.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let delta = UsageInsightsText.delta(product) {
                HStack(spacing: 3) {
                    switch UsageInsightsText.direction(product) {
                    case 1: SVGIcon(ReceiptMetaIcon.trendUp, size: 14, color: k.sub, lineWidth: 2.4)
                    case -1: SVGIcon(ReceiptMetaIcon.trendDown, size: 14, color: k.sub, lineWidth: 2.4)
                    default: EmptyView()
                    }
                    Text(delta)
                        .font(AppFont.dm(11, 600))
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 70, alignment: .trailing)
    }
}

#Preview("Produktzeile", traits: .fixedLayout(width: 390, height: 90)) {
    let usage = ConsumptionStatistics.usage(ArchivedReceipt.insightSamples,
                                            month: ArchivedReceipt.insightSamples[0].purchasedAt, context: .designSample)
    UsageProductRow(product: usage.products[0], month: usage.month, context: .designSample, k: SheetTheme(.light))
}

#Preview("Produktzeile – Dark", traits: .fixedLayout(width: 390, height: 90)) {
    let usage = ConsumptionStatistics.usage(ArchivedReceipt.insightSamples,
                                            month: ArchivedReceipt.insightSamples[0].purchasedAt, context: .designSample)
    UsageProductRow(product: usage.products[3], month: usage.month, context: .designSample, k: SheetTheme(.dark))
        .background(Color.black)
}
