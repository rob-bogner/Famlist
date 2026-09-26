/*
 UserLog+UI.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nutzer-Logs der Kategorie UserLog.UI: App-Start, Navigation und Anzeige.

 📝 Last Change:
 - Aus UserLogger.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension UserLog {
    /// UI-Events
    struct UI {
        static func appLaunched() {
            log("🚀 App gestartet")
        }

        static func mainViewLoaded() {
            log("🏠 Hauptansicht geladen")
        }

        static func viewChanged(to view: String) {
            log("👁️ Wechsel zu \(view)")
        }

        static func loadingImage() {
            log("🖼️ Bild wird geladen...")
        }

        static func imageLoaded() {
            log("✅ Bild geladen")
        }

        static func imageCacheCleared(count: Int) {
            log("🗑️ Bild-Cache geleert (\(count) Bilder)")
        }
    }
}
