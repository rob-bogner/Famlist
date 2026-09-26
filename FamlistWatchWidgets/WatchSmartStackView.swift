/*
 WatchSmartStackView.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Smart-Stack-Karte (.accessoryRectangular, WatchFace.dc.html): Kopf „FAMLIST“ mit Wagen (12, Strich 2,4)
   DM 11/600 Großbuchstaben 0,06em accentText, Titel „My List · 4 offen“ Outfit 16/600 (line-height 1,1),
   Balken 5; Abstand 5; Innenabstand 10/12; Hintergrund Karte (Verlauf weiß .14 → .08).
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

struct WatchSmartStackView: View {
    var w = WatchTheme()
    let state: WatchWidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                SVGIcon(WatchIcon.cart, size: 12, color: w.accentText, lineWidth: 2.4)
                Text("FAMLIST").font(WatchFont.dm(11, 600)).tracking(0.66).foregroundStyle(w.accentText)
            }
            Text("\(state.listName) · \(state.open) offen")
                .font(WatchFont.outfit(16)).foregroundStyle(w.text)
                .watchLineBox(WatchFont.scaled(16) * 1.1)
            WatchProgressBar(w: w, fraction: state.fraction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Famlist, \(state.listName), \(state.open) offen")
    }
}

#Preview(as: .accessoryRectangular) {
    WatchSmartStackWidget()
} timeline: {
    WatchWidgetEntry(date: .now, state: .placeholder)
}
