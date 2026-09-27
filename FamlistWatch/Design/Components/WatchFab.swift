/*
 WatchFab.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - FAB 42 pt (WatchList.dc.html): Orb-Verlauf, Glanz oben (left/right 8, top 3, Höhe 15, Ellipse,
   weiß .55 → 0), Plus 20 pt / Strich 2,8, Schatten inset 0 -3px 8px rgba(0,30,34,.3) und
   0 0 14px rgba(accent,.35).

 🔰 Notes for Beginners:
 - overflow: hidden im Design schneidet nur den Glanz ab, nicht den äußeren Schein → Glanz einzeln
   auf den Kreis beschnitten, Schein von CSSBox unter dem Kreis.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchFab: View {
    var w = WatchTheme()
    var label = "Artikel hinzufügen"
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                CSSBox(shape: Circle(), paint: w.fab, shadows: w.fabShadow)
                GlossEllipse(opacity: 0.55)
                    .frame(width: 26, height: 15)
                    .padding(.top, 3)
                    .frame(width: 42, height: 42, alignment: .top)
                    .clipShape(Circle())
                SVGIcon(Icon.plus, size: 20, color: .white, lineWidth: 2.8)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    WatchFab()
        .padding()
        .background(Color.black)
}
