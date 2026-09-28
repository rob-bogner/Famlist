/*
 ReceiptInsightsCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte „Auswertung <Monat>“ oben im Kassenzettel-Archiv (Board ReceiptArchiveInsights); Tipp öffnet die
   Auswertung im Reiter „Ausgaben“.

 🔰 Notes for Beginners:
 - Board: Padding 14/16, Radius 20, Hero-Verlauf, Schatten wie CTA; Lichtpunkt 140 bei rechts −30 / oben −40
   (weiß 28 % → 0); Kachel 44 (Radius 14, weiß 20 %) mit Balken-Icon 22 (Strich 2,1); Abstand 14;
   Texte 13 weiß 85 % · Outfit 22/600 · 12 weiß 85 % (Abstand 2); Chevron 20 (Strich 2,2) rechts.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptInsightsCard: View {
    let summary: InsightsCardSummary
    let k: SheetTheme
    var onOpen: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                SVGIcon(ReceiptMetaIcon.chart, size: 22, color: .white, lineWidth: 2.1)
                    .frame(width: 44, height: 44)
                    .background(RR(14).fill(Color.rgba(255, 255, 255, 0.2)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                    Text(summary.value)
                        .font(AppFont.outfit(22, 600))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(InsightsCardSummary.subtitle)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SVGIcon(Icon.chevronRight, size: 20, color: .white, lineWidth: 2.2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background {
                // Verlauf und CTA-Schatten (inkl. innerer Schatten) in einer Box; nur der Lichtpunkt wird beschnitten.
                CSSBox(shape: RR(20), paint: ListTheme(k.appearance).heroBg, shadows: k.ctaShadow)
                    .overlay {
                        Color.clear
                            .overlay(alignment: .topTrailing) {
                                RadialGradient(colors: [Color.rgba(255, 255, 255, 0.28), Color.rgba(255, 255, 255, 0)],
                                               center: .center, startRadius: 0, endRadius: 70)
                                    .frame(width: 140, height: 140)
                                    .offset(x: 30, y: -40)
                            }
                            .clipShape(RR(20))
                    }
            }
            .contentShape(RR(20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.title) öffnen")
        .accessibilityValue(summary.value)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Karte Auswertung", traits: .fixedLayout(width: 390, height: 140)) {
    ReceiptInsightsCard(summary: InsightsCardSummary.make(ArchivedReceipt.insightSamples,
                                                          now: ArchivedReceipt.insightSamples[0].purchasedAt)!,
                        k: SheetTheme(.light))
        .padding(20)
}

#Preview("Karte Auswertung – Dark", traits: .fixedLayout(width: 390, height: 140)) {
    ReceiptInsightsCard(summary: InsightsCardSummary.make(ArchivedReceipt.insightSamples,
                                                          now: ArchivedReceipt.insightSamples[0].purchasedAt)!,
                        k: SheetTheme(.dark))
        .padding(20)
        .background(Color.black)
}
