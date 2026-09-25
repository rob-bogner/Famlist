/*
 UserFacingError.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Übersetzt technische Fehler (Netz, Server, Anmeldung) in kurze deutsche Sätze für den Nutzer.

 🔰 Notes for Beginners:
 - Vorher landete `localizedDescription` direkt im UI, z. B. „Status Code: 403 Body: {…}“ oder
   englische Supabase-Texte. `message(for:)` liefert stattdessen einen verständlichen Satz.
 - Eigene Fehler mit deutschem Text (`InviteError`) werden unverändert übernommen.
 - Unbekannte Fehler ergeben den allgemeinen Satz `fallback`.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

enum UserFacingError {
    static let offline = "Keine Internetverbindung. Bitte prüfe deine Verbindung."
    static let timeout = "Der Server antwortet gerade nicht. Bitte versuche es gleich noch einmal."
    static let sessionExpired = "Deine Anmeldung ist abgelaufen. Bitte melde dich erneut an."
    static let forbidden = "Dafür fehlt dir die Berechtigung."
    static let notFound = "Der Eintrag wurde nicht gefunden. Vielleicht wurde er gelöscht."
    static let duplicate = "Diesen Eintrag gibt es bereits."
    static let rateLimited = "Zu viele Versuche. Bitte warte kurz und versuche es dann noch einmal."
    static let invalidCredentials = "E-Mail-Adresse oder Passwort ist falsch."
    static let emailNotConfirmed = "Bitte bestätige zuerst deine E-Mail-Adresse."
    static let userExists = "Für diese E-Mail-Adresse gibt es bereits ein Konto."
    static let weakPassword = "Das Passwort ist zu schwach. Bitte wähle ein längeres Passwort."
    static let fallback = "Das hat nicht geklappt. Bitte versuche es noch einmal."

    /// Deutscher Satz für die Anzeige; nie ein roher Fehlertext.
    static func message(for error: Error) -> String {
        if let invite = error as? InviteError, let text = invite.errorDescription { return text }
        if let url = urlError(from: error) { return message(for: url) }
        if let auth = error as? Auth.AuthError { return message(for: auth) }       // Supabase-Anmeldung
        if case AuthError.unauthenticated? = error as? AuthError { return sessionExpired }   // App-eigener Fehler
        if let http = error as? HTTPError { return message(forStatus: http.response.statusCode) ?? fallback }
        if let pg = error as? PostgrestError { return message(forPostgrestCode: pg.code) ?? fallback }
        return fallback
    }

    // MARK: - Private

    private static func urlError(from error: Error) -> URLError? {
        if let url = error as? URLError { return url }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain ? URLError(URLError.Code(rawValue: ns.code)) : nil
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
            return offline
        case .timedOut:
            return timeout
        default:
            return fallback
        }
    }

    private static func message(for error: Auth.AuthError) -> String {
        switch error.errorCode {
        case .invalidCredentials: return invalidCredentials
        case .emailNotConfirmed: return emailNotConfirmed
        case .userAlreadyExists, .emailExists: return userExists
        case .weakPassword: return weakPassword
        case .overRequestRateLimit: return rateLimited
        case .sessionNotFound: return sessionExpired
        default: break
        }
        if case let .api(_, _, _, response) = error { return message(forStatus: response.statusCode) ?? fallback }
        return fallback
    }

    private static func message(forStatus status: Int) -> String? {
        switch status {
        case 401: return sessionExpired
        case 403: return forbidden
        case 404: return notFound
        case 408, 504: return timeout
        case 429: return rateLimited
        default: return nil
        }
    }

    /// PostgREST-Codes (PGRSTxxx) und SQLSTATE der Datenbank.
    private static func message(forPostgrestCode code: String?) -> String? {
        switch code {
        case "42501": return forbidden              // RLS: keine Berechtigung
        case "PGRST116": return notFound            // keine (oder mehrere) Zeilen
        case "23505": return duplicate              // Eindeutigkeit verletzt
        case "PGRST301", "PGRST302", "PGRST303": return sessionExpired   // JWT abgelaufen/ungültig
        default: return nil
        }
    }
}
