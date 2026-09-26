/*
 WatchSmartStackWidget.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Widget „Famlist – Liste“ für Smart Stack und rechteckige Komplikation.
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

struct WatchSmartStackWidget: Widget {
    static let kind = "FamlistSmartStack"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WatchWidgetProvider()) { entry in
            WatchSmartStackView(state: entry.state)
        }
        .configurationDisplayName("Famlist – Liste")
        .description("Aktive Liste und offene Artikel.")
        .supportedFamilies([.accessoryRectangular])
    }
}
