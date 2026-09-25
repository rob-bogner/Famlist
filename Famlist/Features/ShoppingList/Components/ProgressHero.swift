/*
 ProgressHero.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fortschritts-Karte (Glas-Karte): Padding 18, Radius 28, Inhalt 16 auseinander:
   Icon-Reihe mit Prozentzahl → Balken 10 (ohne Chips, Handoff 24.09.2026).

 🔰 Notes for Beginners:
 - Das Design zeigt nur 0 % (Punkt am Anfang) und 100 % (voller Balken).
   Zwischenwerte füllen den Balken anteilig mit demselben Verlauf.
 - Texte: „0 von 0 Artikeln“, „0 von 1 Artikel“, „1 von 1 Artikel“ (bei Gesamt = 1 Einzahl, Audit 25.09.2026).
   Singular nur, wenn genau ein Artikel da ist und er erledigt ist.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an echte Zahlen angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Glass progress card with percentage, bar and open/done chips.
struct ProgressHero: View {
    let t: ListTheme
    let checked: Int
    let total: Int
    /// Summe Preis × Menge; nil blendet die Zeile aus (Einstellung „Preise anzeigen“ aus).
    var totalPrice: Double? = nil

    private var fraction: Double { total == 0 ? 0 : Double(checked) / Double(total) }
    private var percent: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            ProgressTrack(fraction: fraction)
        }
        .padding(18)
        .background { decoration }
        .background(CSSBox(shape: RR(28), paint: t.heroBg, shadows: t.heroShadow))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fortschritt: \(checked) von \(total) \(Self.itemWord(total: total)) erledigt, \(percent) Prozent"
                            + (totalPrice.map { ", \(PriceDisplaySetting.euro($0)) gesamt" } ?? ""))
    }

    /// „von 1 Artikel“ (Einzahl), sonst „von n Artikeln“.
    static func itemWord(total: Int) -> String { total == 1 ? "Artikel" : "Artikeln" }

    private var headerRow: some View {
        HStack(spacing: 14) {
            // Icon-Kachel: 48 + 1px Rahmen (content-box) = 50 × 50
            SVGIcon(Icon.basket, size: 24, color: .white, lineWidth: 1.9)
                .frame(width: 50, height: 50)
                .background(CSSBox(
                    shape: RR(16),
                    paint: .linear(160, [stop(.rgba(255, 255, 255, 0.4), 0), stop(.rgba(255, 255, 255, 0.14), 1)]),
                    border: 1, borderColor: .rgba(255, 255, 255, 0.45),
                    shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6)),
                              .drop(0, 8, 18, -6, .rgba(0, 30, 34, 0.45))]))

            VStack(alignment: .leading, spacing: 1) {
                Text("Fortschritt")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.86))
                Text("\(checked) von \(total) \(Self.itemWord(total: total))")
                    .font(AppFont.dm(16, 600))
                    .foregroundStyle(Color.white)
                if let totalPrice {
                    // Hybrid.dc.html: margin-top 1, DM Sans 13/500, weiß 0,86
                    Text("\(PriceDisplaySetting.euro(totalPrice)) gesamt")
                        .font(AppFont.dm(13, 500))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .fixedSize()
                        .padding(.top, 1)
                        .contentTransition(.numericText())
                }
            }

            Spacer(minLength: 0)

            Text("\(Text("\(percent)").font(AppFont.outfit(34, 600)).foregroundStyle(Color.white))\(Text(" %").font(AppFont.outfit(17, 600)).foregroundStyle(Color.white.opacity(0.8)))")
                .tracking(-1.02)                                   // -0.03em × 34 (vererbt)
                .shadow(color: .rgba(0, 30, 34, 0.25), radius: 6, x: 0, y: 2) // text-shadow 0 2px 12px
                .contentTransition(.numericText())
        }
    }

    /// Deko-Ebenen (overflow: hidden). Color.clear übernimmt exakt die Kartengröße.
    private var decoration: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                // left -70, top -110, 300×220, radial-gradient(closest-side, rgba(255,255,255,.45), transparent)
                CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                                  stops: [stop(.rgba(255, 255, 255, 0.45), 0), stop(.rgba(255, 255, 255, 0), 1)])
                    .frame(width: 300, height: 220)
                    .offset(x: -70, y: -110)
            }
            .overlay(alignment: .bottomTrailing) {
                // right -50, bottom -80, 200×200 + 1px Rahmen (content-box) = 202×202
                Circle()
                    .strokeBorder(Color.rgba(255, 255, 255, 0.16), lineWidth: 1)
                    .frame(width: 202, height: 202)
                    .offset(x: 50, y: 80)
            }
            .overlay(alignment: .top) {
                // Oberkanten-Lichtlinie, 1 pt
                LinearGradient(stops: [stop(.rgba(255, 255, 255, 0), 0),
                                       stop(.rgba(255, 255, 255, 0.7), 0.5),
                                       stop(.rgba(255, 255, 255, 0), 1)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
            }
            .clipShape(RR(28))
            .allowsHitTesting(false)
    }
}

/// Fortschrittsbalken: Höhe 10, Pille. 0 % = leuchtender Punkt, sonst anteilige Füllung.
private struct ProgressTrack: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if fraction > 0 {
                    Color.clear
                        .frame(width: max(10, geo.size.width * fraction))
                        .background(CSSBox(
                            shape: Pill,
                            paint: .linear(90, [stop(.rgba(255, 255, 255, 0.75), 0), stop(.white, 1)]),
                            shadows: [.drop(0, 0, 12, 2, .rgba(255, 255, 255, 0.6)),
                                      .inner(0, -1, 0, 0, .rgba(0, 40, 45, 0.15))]))
                } else {
                    Color.clear
                        .frame(width: 8, height: 8)
                        .background(CSSBox(shape: Circle(), paint: .color(.white),
                                           shadows: [.drop(0, 0, 10, 3, .rgba(255, 255, 255, 0.75))]))
                        .padding(.leading, 1)
                        .padding(.top, 1)                  // left 1, top 1, 8 × 8
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: fraction)
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
        .background(CSSBox(shape: Pill, paint: .color(.rgba(0, 35, 40, 0.3)),
                           shadows: [.inner(0, 1, 3, 0, .rgba(0, 25, 28, 0.5)),
                                     .drop(0, 1, 0, 0, .rgba(255, 255, 255, 0.25))]))
        .accessibilityHidden(true)
    }
}

#Preview("0 %") { ProgressHero(t: ListTheme(.light), checked: 0, total: 1).padding(20) }
#Preview("60 % Dark") { ProgressHero(t: ListTheme(.dark), checked: 3, total: 5, totalPrice: 12.47).padding(20).background(Color.hex("#071012")) }
