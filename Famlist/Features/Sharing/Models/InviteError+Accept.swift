/*
 InviteError+Accept.swift
 Famlist
 Created on: 04.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Text für einen Fehler beim Annehmen einer Einladung. Nur im iPhone-Target, weil `UserFacingError`
   nicht zur Watch gehört (InviteError.swift wird mit der Watch geteilt).

 🔰 Notes for Beginners:
 - Vorher hieß jeder unbekannte Fehler „Bitte prüfe die Verbindung“ – auch eine fehlende Anmeldung
   (Meldung von Robert 04.10.2026: Konto auf dem Server gelöscht, App hielt sich für angemeldet).

 📝 Last Change:
 - Initial creation (04.10.2026).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

extension InviteError {
    /// Abgelaufen/zurückgezogen → dieser Text; keine gültige Anmeldung → „Anmeldung abgelaufen“; sonst Verbindung.
    static func acceptMessage(for error: Error) -> String {
        if let invite = from(error), let text = invite.errorDescription { return text }
        if isMissingSession(error) { return UserFacingError.sessionExpired }
        return InviteError.acceptFailed.errorDescription ?? UserFacingError.fallback
    }

    /// Die Einladungs-Funktionen dürfen alle angemeldeten Nutzer ausführen, nicht angemeldete nicht
    /// (live geprüft 04.10.2026). „permission denied“ (42501) heißt hier deshalb: keine gültige Anmeldung.
    static func isMissingSession(_ error: Error) -> Bool {
        if let pg = error as? PostgrestError, pg.code == "42501" { return true }
        return UserFacingError.message(for: error) == UserFacingError.sessionExpired
    }
}
