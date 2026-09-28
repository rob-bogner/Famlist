/*
 CategoryShareBar.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gestapelter Balken „Nach Kategorie“ (Board InsightSpend): ein Abschnitt je Kategorie in ihrer Farbe.

 🔰 Notes for Beginners:
 - Board: Höhe 12, Radius 6, Abstand 2; Breite je Abschnitt wie `flex: <Betrag>` (Anteil am Rest nach Abständen).
 - Negative Beträge (Rabatte größer als Zeilen) bekommen keinen Abschnitt.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CategoryShareBar: View {
    let shares: [SpendInsights.CategoryShare]
    let dark: Bool

    var body: some View {
        GeometryReader { proxy in
            let visible = shares.filter { $0.amount > 0 }
            let sum = visible.reduce(0.0) { $0 + value($1.amount) }
            let free = proxy.size.width - 2 * CGFloat(max(visible.count - 1, 0))
            HStack(spacing: 2) {
                ForEach(visible) { share in
                    Rectangle()
                        .fill(InsightPalette.color(rank: share.rank, dark: dark))
                        .frame(width: sum > 0 ? free * CGFloat(value(share.amount) / sum) : 0)
                }
            }
        }
        .frame(height: 12)
        .clipShape(RR(6))
        .accessibilityHidden(true)
    }

    private func value(_ decimal: Decimal) -> Double { NSDecimalNumber(decimal: decimal).doubleValue }
}

#Preview("Kategorie-Balken") {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    CategoryShareBar(shares: spend.categories, dark: false).padding(20)
}

#Preview("Kategorie-Balken – Dark") {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    CategoryShareBar(shares: spend.categories, dark: true).padding(20).background(Color.black)
}
