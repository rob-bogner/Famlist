/*
 UserLog+UI.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nutzer-Logs der Kategorie UserLog.UI: App-Start, Navigation und Anzeige.

 📝 Last Change:
 - Auswertung der Kassenzettel: geöffnet, Monat gewechselt (Einkaufsdaten & Auswertung).
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

        /// Kassenzettel-Auswertung geöffnet („September 2026“).
        static func insightsOpened(month: String) {
            log("📊 Auswertung geöffnet (\(month))")
        }

        /// Kassenzettel-Auswertung: anderer Monat.
        static func insightsMonthChanged(to month: String) {
            log("📊 Monat gewechselt: \(month)")
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
