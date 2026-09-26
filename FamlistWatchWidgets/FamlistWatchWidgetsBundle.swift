/*
 FamlistWatchWidgetsBundle.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstieg der Widget-Erweiterung (watchOS 10+): Smart Stack und zwei Komplikationen (Watch-Plan §6).
 ------------------------------------------------------------------------
 */

import SwiftUI
import WidgetKit

@main
struct FamlistWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchSmartStackWidget()
        WatchRingWidget()
        WatchAddWidget()
    }
}
