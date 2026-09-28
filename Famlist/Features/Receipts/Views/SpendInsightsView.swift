/*
 SpendInsightsView.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt des Reiters „Ausgaben“ (Board InsightSpend): Hero, „Letzte 6 Monate“, „Nach Kategorie“, „Nach Laden“.

 🔰 Notes for Beginners:
 - Abstände aus dem Board: Hero 14 unter dem Monatswechsel, Abschnitte 20, Karte 8 unter ihrer Überschrift.
 - Monat ohne Bons: nur der Hero („0,00 €“, Chip „Keine Einkäufe“), Abschnitte ausgeblendet (Auftrag §6).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SpendInsightsView: View {
    let spend: SpendInsights
    let context: ReceiptLineContext
    let t: ListAccountTokens

    var body: some View {
        VStack(spacing: 0) {
            InsightHeroCard(title: SpendInsightsText.heroTitle(spend), value: SpendInsightsText.heroValue(spend),
                            chips: SpendInsightsText.chips(spend), appearance: t.k.appearance)
                .padding(.top, 14)
            if !spend.isEmpty {
                InsightSectionHeader(title: "Letzte 6 Monate", trailing: SpendInsightsText.barAverage(spend), k: t.k)
                    .padding(.top, 20)
                InsightBarChart(bars: spend.bars, average: spend.barAverage, t: t)
                    .insightCard(t, top: 14, horizontal: 14, bottom: 8)
                    .padding(.top, 8)
                InsightSectionHeader(title: "Nach Kategorie", k: t.k)
                    .padding(.top, 20)
                SpendCategoriesCard(shares: spend.categories, context: context, t: t)
                    .padding(.top, 8)
                InsightSectionHeader(title: "Nach Laden", k: t.k)
                    .padding(.top, 20)
                SpendStoresCard(stores: spend.stores, t: t)
                    .padding(.top, 8)
            }
        }
    }
}

#Preview("Ausgaben", traits: .fixedLayout(width: 390, height: 1100)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    ScrollView { SpendInsightsView(spend: spend, context: .designSample, t: ListAccountTokens(.light)).padding(20) }
}

#Preview("Ausgaben – Dark", traits: .fixedLayout(width: 390, height: 1100)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    ScrollView { SpendInsightsView(spend: spend, context: .designSample, t: ListAccountTokens(.dark)).padding(20) }
        .background(Color.black)
}
