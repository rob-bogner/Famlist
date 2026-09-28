/*
 InsightHeroCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hero der Auswertung (InsightSpend „Ausgegeben im September · 412,37 €“, InsightUsage „Milch im September ·
   14 Liter“): Verlauf in Akzentfarbe, Lichtpunkt oben rechts, Titel, großer Wert, Chips.

 🔰 Notes for Beginners:
 - Board: Padding 16, Radius 22, heroBg; Lichtpunkt 170 × 170 bei rechts −40 / oben −50 (weiß 26 % → 0);
   Abstand 4; Titel 13 weiß 85 %; Wert Outfit 34/600, Laufweite −0,01 em; Chips ab 6 darunter (InsightChipFlow).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InsightHeroCard: View {
    let title: String
    let value: String
    let chips: [String]
    let appearance: Appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.dm(13, 400))
                .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
            Text(value)
                .font(AppFont.outfit(34, 600))
                .tracking(-0.34)
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            InsightChipFlow(spacing: 6) {
                ForEach(chips, id: \.self) { InsightChip(text: $0) }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            // Lichtpunkt als Overlay: bestimmt so nicht die Größe der Karte (170 pt wären höher als der Inhalt).
            CSSBox(shape: RR(22), paint: ListTheme(appearance).heroBg)
                .overlay(alignment: .topTrailing) {
                    RadialGradient(colors: [Color.rgba(255, 255, 255, 0.26), Color.rgba(255, 255, 255, 0)],
                                   center: .center, startRadius: 0, endRadius: 85)
                        .frame(width: 170, height: 170)
                        .offset(x: 40, y: -50)
                }
                .clipShape(RR(22))
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Hero", traits: .fixedLayout(width: 390, height: 220)) {
    InsightHeroCard(title: "Ausgegeben im September", value: "412,37 €",
                    chips: ["↑ 8 % ggü. August", "9 Einkäufe", "Ø 45,82 €"], appearance: .light)
        .padding(20)
}

#Preview("Hero – Dark", traits: .fixedLayout(width: 390, height: 220)) {
    InsightHeroCard(title: "Milch im September", value: "14 Liter",
                    chips: ["3,5 l pro Woche", "↑ 2 l ggü. August", "16,66 €"], appearance: .dark)
        .padding(20)
        .background(Color.black)
}
