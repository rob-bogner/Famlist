/*
 WatchAddComplicationView.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Plus-Komplikation (.accessoryCircular, WatchFace.dc.html): Kreis 44 weiß .1, Plus 20 / Strich 2,4 in
   accentText (Original-SVG-Pfad). Tipp öffnet „Hinzufügen“ (famlist://watch/add).
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

struct WatchAddComplicationView: View {
    var w = WatchTheme()

    var body: some View {
        SVGIcon(Icon.plus, size: 20, color: w.accentText, lineWidth: 2.4)
            .containerBackground(for: .widget) { Color.white.opacity(0.1) }
            .widgetURL(URL(string: "famlist://watch/add"))
            .accessibilityLabel("Artikel hinzufügen")
    }
}

#Preview(as: .accessoryCircular) {
    WatchAddWidget()
} timeline: {
    WatchWidgetEntry(date: .now, state: .placeholder)
}
