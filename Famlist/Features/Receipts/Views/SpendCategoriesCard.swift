/*
 SpendCategoriesCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte „Nach Kategorie“ (Board InsightSpend): gestapelter Balken, darunter je Kategorie Kachel, Name,
   Anteil und Betrag.

 🔰 Notes for Beginners:
 - Board: Karte Padding 14/14/4, Balken, Zeilen ab 8; Zeile Padding 9/0, Abstand 12; Kachel 30 (Radius 10,
   Icon 16); Name 14/600; Anteil 12 sub rechtsbündig in 38; Betrag 14/600 rechtsbündig in 72;
   Trennlinie k.line über jeder Zeile außer der ersten.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SpendCategoriesCard: View {
    let shares: [SpendInsights.CategoryShare]
    let context: ReceiptLineContext
    let t: ListAccountTokens

    var body: some View {
        VStack(spacing: 0) {
            CategoryShareBar(shares: shares, dark: t.isDark)
            VStack(spacing: 0) {
                ForEach(shares) { share in
                    if share.id != shares.first?.id {
                        Rectangle().fill(t.line).frame(height: 1)
                    }
                    row(share)
                }
            }
            .padding(.top, 8)
        }
        .insightCard(t, top: 14, horizontal: 14, bottom: 4)
    }

    private func row(_ share: SpendInsights.CategoryShare) -> some View {
        let k = t.k
        return HStack(spacing: 12) {
            CategoryTile(category: context.definition(named: share.name), rank: share.rank, size: 30, radius: 10,
                         iconSize: 16, dark: t.isDark)
            Text(share.name)
                .font(AppFont.dm(14, 600))
                .foregroundStyle(k.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SpendInsightsText.percent(share))
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
                .frame(width: 38, alignment: .trailing)
            Text(InsightFormat.euro(share.amount))
                .font(AppFont.dm(14, 600))
                .foregroundStyle(k.text)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(share.name), \(SpendInsightsText.percent(share)), \(InsightFormat.euro(share.amount))")
    }
}

#Preview("Nach Kategorie", traits: .fixedLayout(width: 390, height: 420)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    SpendCategoriesCard(shares: spend.categories, context: .designSample, t: ListAccountTokens(.light)).padding(20)
}

#Preview("Nach Kategorie – Dark", traits: .fixedLayout(width: 390, height: 420)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    SpendCategoriesCard(shares: spend.categories, context: .designSample, t: ListAccountTokens(.dark))
        .padding(20)
        .background(Color.black)
}
