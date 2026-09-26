/*
 CompactProgressBar.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schmale Fortschrittsleiste des kompakten Listenkopfs (beim Scrollen): 40 hoch statt Fortschrittskarte.

 🔰 Notes for Beginners:
 - Vorlage: Hybrid.dc.html, Prop header = "compact" (Canvas „Liste – Kopf kompakt“, 26.09.2026).
 - Reihe: „x von y Artikeln“ (DM 13/600) · Balken 6 hoch (füllt den Rest) · Summe (DM 13/500, optional) · „n %“.
 - Hintergrund wie die große Karte (heroBg), Schatten kleiner: 0 12 24 -12 Akzent.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CompactProgressBar: View {
    let t: ListTheme
    let checked: Int
    let total: Int
    /// Summe Preis × Menge; nil blendet sie aus („Preise anzeigen“ aus).
    var totalPrice: Double? = nil

    private var fraction: Double { total == 0 ? 0 : Double(checked) / Double(total) }
    private var percent: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(checked) von \(total) \(checked == 1 && total == 1 ? "Artikel" : "Artikeln")")
                .font(AppFont.dm(13, 600))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .fixedSize()
            track
            if let totalPrice {
                Text(PriceDisplaySetting.euro(totalPrice))
                    .font(AppFont.dm(13, 500))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.86))
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText())
            }
            Text("\(Text("\(percent)").font(AppFont.outfit(17, 600)))\(Text(" %").font(AppFont.outfit(12, 600)).foregroundStyle(Color.white.opacity(0.8)))")
                .foregroundStyle(Color.white)
                .tracking(-0.34)                                     // -0.02em × 17
                .fixedSize()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(alignment: .top) {
            // Lichtkante oben: 1 px, links/rechts transparent
            LinearGradient(stops: [stop(.rgba(255, 255, 255, 0), 0), stop(.rgba(255, 255, 255, 0.7), 0.5),
                                   stop(.rgba(255, 255, 255, 0), 1)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .clipShape(RR(20))
        .background(CSSBox(shape: RR(20), paint: t.heroBg,
                           shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.35)),
                                     .inner(0, -1, 0, 0, .rgba(0, 30, 34, 0.2)),
                                     .drop(0, 12, 24, -12, t.a.base.color(t.isDark ? 0.6 : 0.65))]))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fortschritt: \(checked) von \(total) Artikeln erledigt, \(percent) Prozent"
                            + (totalPrice.map { ", \(PriceDisplaySetting.euro($0)) gesamt" } ?? ""))
    }

    /// Balken 6 hoch; 0 %: Punkt 4 × 4 (links/oben 1), sonst Füllung anteilig.
    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if fraction > 0 {
                    Color.clear
                        .frame(width: max(6, geo.size.width * fraction))
                        .background(CSSBox(shape: Pill,
                                           paint: .linear(90, [stop(.rgba(255, 255, 255, 0.75), 0), stop(.white, 1)]),
                                           shadows: [.drop(0, 0, 8, 1, .rgba(255, 255, 255, 0.6))]))
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .shadow(color: .rgba(255, 255, 255, 0.75), radius: 3)
                        .padding(1)
                }
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: fraction)
        }
        .frame(height: 6)
        .background(CSSBox(shape: Pill, paint: .color(.rgba(0, 35, 40, 0.3)),
                           shadows: [.inner(0, 1, 2, 0, .rgba(0, 25, 28, 0.5)), .drop(0, 1, 0, 0, .rgba(255, 255, 255, 0.25))]))
    }
}

#Preview("Kompakt") {
    VStack(spacing: 16) {
        CompactProgressBar(t: ListTheme(.light), checked: 0, total: 1, totalPrice: 1.49)
        CompactProgressBar(t: ListTheme(.light), checked: 3, total: 5)
    }
    .padding(20)
}

#Preview("Kompakt – Dark") {
    CompactProgressBar(t: ListTheme(.dark), checked: 5, total: 5, totalPrice: 12.47)
        .padding(20)
        .background(Color.hex("#071012"))
}
