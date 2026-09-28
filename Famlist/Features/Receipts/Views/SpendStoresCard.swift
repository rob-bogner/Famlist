/*
 SpendStoresCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte „Nach Laden“ (Board InsightSpend): je Laden Name, „<n> × · Ø <Betrag>“, Summe und ein Balken
   relativ zum Laden mit der größten Summe.

 🔰 Notes for Beginners:
 - Board: Karte Padding 4/14; Zeile Padding 10/0, Abstand 6; Kopfzeile auf gemeinsamer Grundlinie, Abstand 8:
   Name 14/600, Angabe 12 sub, Summe 14/600 rechtsbündig in 72; Balken 6 hoch, Radius 3, segBg, Füllung Akzent.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SpendStoresCard: View {
    let stores: [SpendInsights.StoreShare]
    let t: ListAccountTokens

    var body: some View {
        VStack(spacing: 0) {
            ForEach(stores) { store in
                if store.id != stores.first?.id {
                    Rectangle().fill(t.line).frame(height: 1)
                }
                row(store)
            }
        }
        .insightCard(t, top: 4, horizontal: 14, bottom: 4)
    }

    private func row(_ store: SpendInsights.StoreShare) -> some View {
        let k = t.k
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.name)
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(SpendInsightsText.storeDetail(store))
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .fixedSize()
                Text(InsightFormat.euro(store.total))
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.text)
                    .frame(width: 72, alignment: .trailing)
            }
            GeometryReader { proxy in
                RR(3).fill(t.segBg)
                    .overlay(alignment: .leading) {
                        RR(3).fill(k.accent).frame(width: proxy.size.width * CGFloat(store.fraction))
                    }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.name), \(SpendInsightsText.storeDetail(store)), \(InsightFormat.euro(store.total))")
    }
}

#Preview("Nach Laden", traits: .fixedLayout(width: 390, height: 300)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    SpendStoresCard(stores: spend.stores, t: ListAccountTokens(.light)).padding(20)
}

#Preview("Nach Laden – Dark", traits: .fixedLayout(width: 390, height: 300)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    SpendStoresCard(stores: spend.stores, t: ListAccountTokens(.dark)).padding(20).background(Color.black)
}
