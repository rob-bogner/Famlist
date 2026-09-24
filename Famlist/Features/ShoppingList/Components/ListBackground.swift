/*
 ListBackground.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hintergrund des Listen-Screens: Light weiß, Dark #071012 mit Akzent-Verlauf von unten
   und zwei weichgezeichneten Leuchtflächen.

 🔰 Notes for Beginners:
 - Liegt hinter dem scrollenden Inhalt und füllt auch die Safe Area.
 - Die Leuchtflächen sind absolut positioniert (links −120 / oben 360 und rechts −140 / oben 560).

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Screen background incl. dark-mode glows.
struct ListBackground: View {
    let t: ListTheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            base
            if t.isDark {
                // left: -120; top: 360; 320×320; filter: blur(70px)
                Circle()
                    .fill(t.glowA)
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: -120, y: 360)
                // right: -140; top: 560; 300×300; filter: blur(80px)
                Circle()
                    .fill(Color.rgba(90, 120, 255, 0.14))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: 140, y: 560)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var base: some View {
        if t.isDark {
            // radial-gradient(120% 60% at 50% 100%, rgba(accent,.1), rgba(0,0,0,0) 60%), #071012
            ZStack {
                Color.hex("#071012")
                CSSRadialGradient(center: UnitPoint(x: 0.5, y: 1),
                                  extent: .ellipse(rx: 1.2, ry: 0.6),
                                  stops: [stop(t.a.base.color(0.1), 0), stop(t.a.base.color(0), 0.6)])
            }
        } else {
            Color.white
        }
    }
}

#Preview("Light") { ListBackground(t: ListTheme(.light)) }
#Preview("Dark") { ListBackground(t: ListTheme(.dark)) }
