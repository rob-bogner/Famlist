/*
 WatchRingComplicationView.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runde Komplikation (.accessoryCircular, WatchFace.dc.html): Kreis 44 weiß .1, Ring 38 / Strich 4 mit
   Anteil erledigt, offene Anzahl DM 11/600. Tipp öffnet die Liste (famlist://watch/list).
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

struct WatchRingComplicationView: View {
    var w = WatchTheme()
    let state: WatchWidgetState

    var body: some View {
        WatchRing(w: w, fraction: state.fraction, size: 38, lineWidth: 4, label: "\(state.open)")
            .containerBackground(for: .widget) { Color.white.opacity(0.1) }
            .widgetURL(URL(string: "famlist://watch/list"))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state.listName), \(state.open) offen")
    }
}

#Preview(as: .accessoryCircular) {
    WatchRingWidget()
} timeline: {
    WatchWidgetEntry(date: .now, state: .placeholder)
}
