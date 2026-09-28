/*
 UsageInsightsView.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt des Reiters „Verbrauch“ (Board InsightUsage): Suchfeld, Hero mit dem meistgekauften Produkt,
   „Am meisten gekauft“ mit Menge und Verlauf über 6 Monate.

 🔰 Notes for Beginners:
 - Abstände aus dem Board: Suchfeld 14 unter dem Monatswechsel, Hero 14, Abschnitt 20, Karte 8.
 - Die Suche filtert nur die Liste; der Hero bleibt beim meistgekauften Produkt des Monats.
 - Keine Treffer: „Kein Produkt gefunden“ (14, sub) mittig in der Karte. Monat ohne Käufe: nur der Hero
   (Auftrag §6, nicht gestaltet).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct UsageInsightsView: View {
    let usage: UsageInsights
    let products: [UsageInsights.Product]
    @Binding var search: String
    let context: ReceiptLineContext
    let t: ListAccountTokens
    var onOpen: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            InsightSearchField(text: $search, k: t.k)
                .padding(.top, 14)
            InsightHeroCard(title: UsageInsightsText.heroTitle(usage), value: UsageInsightsText.heroValue(usage),
                            chips: UsageInsightsText.chips(usage), appearance: t.k.appearance)
                .padding(.top, 14)
            if !usage.isEmpty {
                InsightSectionHeader(title: "Am meisten gekauft", trailing: "Menge · Verlauf 6 Monate", k: t.k)
                    .padding(.top, 20)
                list
                    .padding(.top, 8)
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            if products.isEmpty {
                Text(UsageInsightsText.notFound)
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(t.k.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            ForEach(products) { product in
                if product.id != products.first?.id {
                    Rectangle().fill(t.line).frame(height: 1)
                }
                UsageProductRow(product: product, month: usage.month, context: context, k: t.k, onOpen: onOpen)
            }
        }
        .insightCard(t, top: 0, horizontal: 0, bottom: 0)
    }
}

#Preview("Verbrauch", traits: .fixedLayout(width: 390, height: 1000)) {
    let usage = ConsumptionStatistics.usage(ArchivedReceipt.insightSamples,
                                            month: ArchivedReceipt.insightSamples[0].purchasedAt, context: .designSample)
    ScrollView {
        UsageInsightsView(usage: usage, products: usage.products, search: .constant(""), context: .designSample,
                          t: ListAccountTokens(.light))
            .padding(20)
    }
}

#Preview("Verbrauch – Dark", traits: .fixedLayout(width: 390, height: 1000)) {
    let usage = ConsumptionStatistics.usage(ArchivedReceipt.insightSamples,
                                            month: ArchivedReceipt.insightSamples[0].purchasedAt, context: .designSample)
    ScrollView {
        UsageInsightsView(usage: usage, products: [], search: .constant("Zucchinibrot"), context: .designSample,
                          t: ListAccountTokens(.dark))
            .padding(20)
    }
    .background(Color.black)
}
