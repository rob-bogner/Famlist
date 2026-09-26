/*
 UserLog+Sync.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nutzer-Logs der Kategorie UserLog.Sync: Start, Abschluss und Fehler der Synchronisierung.

 📝 Last Change:
 - Aus UserLogger.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension UserLog {
    /// Synchronisierungs-Events
    struct Sync {
        static func started() {
            log("🔄 Synchronisierung gestartet")
        }

        static func syncing(itemCount: Int) {
            log("☁️ Synchronisiere \(itemCount) Artikel mit Server...")
        }

        static func completed(itemCount: Int? = nil) {
            if let count = itemCount {
                log("✅ Synchronisierung abgeschlossen (\(count) Artikel)")
            } else {
                log("✅ Synchronisierung abgeschlossen")
            }
        }

        static func failed(reason: String? = nil) {
            if let reason = reason {
                log("⚠️ Synchronisierung fehlgeschlagen: \(reason)")
            } else {
                log("⚠️ Synchronisierung fehlgeschlagen")
            }
        }

        static func realtimeUpdate(itemName: String? = nil) {
            if let itemName = itemName {
                log("📡 Echtzeit-Update empfangen für '\(itemName)'")
            } else {
                log("📡 Echtzeit-Update empfangen")
            }
        }

        static func offlineMode() {
            log("📴 Offline-Modus: Änderungen werden lokal gespeichert")
        }

        static func onlineMode() {
            log("📶 Verbindung wiederhergestellt - Synchronisierung läuft")
        }

        static func supabaseInitialized(host: String) {
            log("🔌 Verbindung zu Supabase-Server (\(host)) wird hergestellt...")
        }

        static func realtimePaused(listName: String? = nil) {
            if let listName = listName {
                log("⏸️ Echtzeit-Updates für '\(listName)' pausiert (App im Hintergrund)")
            } else {
                log("⏸️ Echtzeit-Updates pausiert (App im Hintergrund)")
            }
        }

        static func realtimeDisconnected(listName: String? = nil) {
            if let listName = listName {
                log("📴 Echtzeit-Verbindung für '\(listName)' getrennt")
            } else {
                log("📴 Echtzeit-Verbindung getrennt")
            }
        }

        static func realtimeResumed(listName: String? = nil) {
            if let listName = listName {
                log("▶️ Echtzeit-Updates für '\(listName)' fortgesetzt")
            } else {
                log("▶️ Echtzeit-Updates fortgesetzt")
            }
        }

        /// Sync endgültig fehlgeschlagen nach max. Retries
        /// → "⚠️ Synchronisierung fehlgeschlagen: Eier"
        static func itemSyncFailed(name: String, units: Int, measure: String) {
            log("⚠️ Synchronisierung fehlgeschlagen: \(name)")
        }
    }
}
