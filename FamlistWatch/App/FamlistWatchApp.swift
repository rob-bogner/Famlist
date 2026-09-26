/*
 FamlistWatchApp.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstiegspunkt der Watch-App (watchOS 10+), Companion der iOS-App.

 🔰 Notes for Beginners:
 - Phase 1 (design-handoff/WATCH_PLAN.md §8): nur das Gerüst. Screens folgen in Phase 2,
   Sync und Anmeldung in Phase 4.
 ------------------------------------------------------------------------
 */

import SwiftUI

@main
struct FamlistWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Famlist")
        }
    }
}
