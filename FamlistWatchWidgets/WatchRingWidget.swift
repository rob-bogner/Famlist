/*
 WatchRingWidget.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Komplikation „Offen“: Ring mit Anteil erledigt und offener Anzahl.
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

struct WatchRingWidget: Widget {
    static let kind = "FamlistRing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WatchWidgetProvider()) { entry in
            WatchRingComplicationView(state: entry.state)
        }
        .configurationDisplayName("Famlist – Offen")
        .description("Offene Artikel der aktiven Liste.")
        .supportedFamilies([.accessoryCircular])
    }
}
