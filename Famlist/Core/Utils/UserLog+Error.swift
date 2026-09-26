/*
 UserLog+Error.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nutzer-Logs der Kategorie UserLog.Error: Fehlermeldungen, die den Nutzer betreffen.

 📝 Last Change:
 - Aus UserLogger.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension UserLog {
    /// Fehler-Events
    struct Error {
        static func general(message: String) {
            log("❌ FEHLER: \(message)")
        }

        static func network(message: String? = nil) {
            if let message = message {
                log("🌐 Netzwerkfehler: \(message)")
            } else {
                log("🌐 Netzwerkfehler: Keine Verbindung zum Server")
            }
        }

        static func database(message: String) {
            log("💾 Datenbankfehler: \(message)")
        }

        static func validation(field: String, message: String) {
            log("⚠️ Eingabefehler bei \(field): \(message)")
        }

        static func unexpected(details: String? = nil) {
            if let details = details {
                log("❗️ Unerwarteter Fehler: \(details)")
            } else {
                log("❗️ Unerwarteter Fehler aufgetreten")
            }
        }
    }
}
