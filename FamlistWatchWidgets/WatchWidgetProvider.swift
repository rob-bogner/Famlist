/*
 WatchWidgetProvider.swift
 FamlistWatchWidgets
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeitleiste der Widgets: liest nur den Stand aus der App Group (keine Netzabfrage, Watch-Plan §6).
   Neu geladen wird, wenn die Uhr-App einen geänderten Stand schreibt (WatchWidgetPublisher).
 ------------------------------------------------------------------------
 */

import WidgetKit

struct WatchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        completion(entry(preview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        completion(Timeline(entries: [entry(preview: false)], policy: .never))
    }

    private func entry(preview: Bool) -> WatchWidgetEntry {
        let stored = WatchWidgetState.load(from: WatchWidgetState.sharedDefaults)
        return WatchWidgetEntry(date: Date(), state: stored ?? (preview ? .placeholder : .empty))
    }
}
