/*
 DesignProgressHero.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fortschritts-Karte (Glas-Karte mit Balken) der statischen Design-Liste für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Fortschritt (Glas-Karte, ohne Chips)

struct DesignProgressHero: View {
    let t: ListTheme
    let state: ListRowState

    private var checked: Bool { state == .checked }

    private var label: String {
        switch state {
        case .empty: "0 von 0 Artikeln"
        case .checked: "1 von 1 Artikel"
        case .normal, .swipe: "0 von 1 Artikeln"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    Text(label)
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(Color.white)
                }

                Spacer(minLength: 0)

                Text("\(Text(checked ? "100" : "0").font(AppFont.outfit(34, 600)).foregroundStyle(Color.white))\(Text(" %").font(AppFont.outfit(17, 600)).foregroundStyle(Color.white.opacity(0.8)))")
                    .tracking(-1.02)                                   // -0.03em × 34 (vererbt)
                    .shadow(color: .rgba(0, 30, 34, 0.25), radius: 6, x: 0, y: 2) // text-shadow 0 2px 12px
            }

            DesignProgressTrack(filled: checked)
        }
        .padding(18)
        .background {
            // Deko-Ebenen (overflow: hidden). Color.clear übernimmt exakt die Kartengröße,
            // die Overlays beeinflussen das Layout nicht.
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
        .background(CSSBox(shape: RR(28), paint: t.heroBg, shadows: t.heroShadow))
    }
}

private struct DesignProgressTrack: View {
    let filled: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if filled {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CSSBox(
                        shape: Pill,
                        paint: .linear(90, [stop(.rgba(255, 255, 255, 0.75), 0), stop(.white, 1)]),
                        shadows: [.drop(0, 0, 12, 2, .rgba(255, 255, 255, 0.6)),
                                  .inner(0, -1, 0, 0, .rgba(0, 40, 45, 0.15))]))
            } else {
                // left 1, top 1, 8 × 8
                Color.clear
                    .frame(width: 8, height: 8)
                    .background(CSSBox(shape: Circle(), paint: .color(.white),
                                       shadows: [.drop(0, 0, 10, 3, .rgba(255, 255, 255, 0.75))]))
                    .padding(.leading, 1)
                    .padding(.top, 1)
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
        .background(CSSBox(shape: Pill, paint: .color(.rgba(0, 35, 40, 0.3)),
                           shadows: [.inner(0, 1, 3, 0, .rgba(0, 25, 28, 0.5)),
                                     .drop(0, 1, 0, 0, .rgba(255, 255, 255, 0.25))]))
        .accessibilityHidden(true)
    }
}

#Preview("Fortschritt") {
    DesignProgressHero(t: ListTheme(.light), state: .normal)
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Fortschritt – Dark") {
    DesignProgressHero(t: ListTheme(.dark), state: .checked)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
