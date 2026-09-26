/*
 FamlistWatchApp.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstiegspunkt der Watch-App (watchOS 10+), Companion der iOS-App.

 🔰 Notes for Beginners:
 - Phase 2 (design-handoff/WATCH_PLAN.md §8): Screens mit Beispieldaten. Echte Daten, Sync und
   Anmeldung folgen in Phase 4/5.
 - DEBUG: `-watchDesignScreen <name>` zeigt einen Screen für den Pixelvergleich (WatchDesignGallery).
 ------------------------------------------------------------------------
 */

import SwiftUI

@main
struct FamlistWatchApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            WatchDesignGallery(screen: WatchDesignGallery.requestedScreen ?? "list")
            #else
            NavigationStack {
                WatchListScreen(title: "Famlist", checked: 0, total: 0, sections: [])
            }
            #endif
        }
    }
}
