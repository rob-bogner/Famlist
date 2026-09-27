/*
 WatchWidgetEntry.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Zeitpunkt der Widget-Zeitleiste mit dem Stand aus der App Group.
 ------------------------------------------------------------------------
 */

import WidgetKit

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let state: WatchWidgetState
}
