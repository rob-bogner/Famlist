/*
 WatchAddWidget.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Komplikation „Hinzufügen“: öffnet direkt den Screen „Hinzufügen“.
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

struct WatchAddWidget: Widget {
    static let kind = "FamlistAdd"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WatchWidgetProvider()) { _ in
            WatchAddComplicationView()
        }
        .configurationDisplayName("Famlist – Hinzufügen")
        .description("Artikel per Diktat hinzufügen.")
        .supportedFamilies([.accessoryCircular])
    }
}
