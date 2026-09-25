/*
 InviteError.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fehler rund um Einladungslinks mit Token (Migration 014).

 🔰 Notes for Beginners:
 - `invalidOrExpired`: Der Server kennt den Token nicht (mehr) – abgelaufen nach 14 Tagen,
   widerrufen, weil der Besitzer ein Mitglied entfernt hat, oder ein alter Link im Listen-ID-Format.
 - `from(_:)` erkennt den Server-Fehler am PostgREST-Code P0002 bzw. am Text der Exception.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Einladungen mit Token).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

enum InviteError: Error, Equatable, LocalizedError {
    case invalidOrExpired
    case unavailable
    case acceptFailed

    var errorDescription: String? {
        switch self {
        case .invalidOrExpired: return "Diese Einladung ist abgelaufen oder wurde zurückgezogen. Bitte um einen neuen Link."
        case .unavailable: return "Der Einladungslink kann gerade nicht erstellt werden. Bitte prüfe die Verbindung."
        case .acceptFailed: return "Die Einladung konnte nicht angenommen werden. Bitte prüfe die Verbindung."
        }
    }

    /// Ordnet einen Server-Fehler der RPC accept_list_invite ein; nil = anderer Fehler (z. B. Netzwerk).
    static func from(_ error: Error) -> InviteError? {
        if let invite = error as? InviteError { return invite }
        if let pg = error as? PostgrestError {
            if pg.code == "P0002" || pg.message.contains("invite invalid or expired") { return .invalidOrExpired }
        }
        return nil
    }
}
