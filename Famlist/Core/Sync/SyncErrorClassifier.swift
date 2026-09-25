/*
 SyncErrorClassifier.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ordnet Fehler beim Senden der Sync-Warteschlange ein: vorübergehend oder dauerhaft.

 🔰 Notes for Beginners:
 - Vorübergehend (Funkloch, Zeitüberschreitung, Serverfehler 5xx, 408/429, abgelaufenes Token):
   Die Operation bleibt in der Warteschlange und wird später erneut gesendet – ohne Limit.
   Vorher gab die App nach 5 Fehlversuchen (≈ 30–60 s) für immer auf, auch wenn nur das Netz fehlte.
 - Dauerhaft (z. B. kein Zugriff mehr, ungültige Daten): Weitere Versuche ändern nichts.
   Der Artikel wird als „fehlgeschlagen“ markiert und kann manuell erneut versucht werden.
 - `isOffline`: reine Verbindungsfehler; dann bricht die Engine den ganzen Durchlauf ab.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Sync-Kern K2).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

enum SyncErrorClassifier {
    enum Kind: Equatable {
        case offline
        case transient
        case permanent
    }

    static func classify(_ error: Error) -> Kind {
        if error is CancellationError { return .transient }
        if let url = error as? URLError { return classify(url) }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return classify(URLError(URLError.Code(rawValue: ns.code))) }
        if let http = error as? HTTPError { return classify(status: http.response.statusCode) }
        if let pg = error as? PostgrestError { return classify(postgrestCode: pg.code) }
        if error is DecodingError || error is EncodingError { return .permanent }
        return .transient
    }

    private static func classify(_ error: URLError) -> Kind {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
            return .offline
        case .badURL, .unsupportedURL:
            return .permanent
        default:
            return .transient
        }
    }

    private static func classify(status: Int) -> Kind {
        switch status {
        case 401, 408, 425, 429, 500...599: return .transient
        case 400...499: return .permanent
        default: return .transient
        }
    }

    /// PostgREST-Codes (PGRSTxxx) und SQLSTATE der Datenbank.
    private static func classify(postgrestCode code: String?) -> Kind {
        guard let code else { return .transient }
        if code.hasPrefix("PGRST3") { return .transient }          // JWT abgelaufen/ungültig → Token-Refresh
        if code.hasPrefix("08") || code.hasPrefix("53") || code.hasPrefix("57") || code == "40001" || code == "40P01" {
            return .transient                                      // Verbindung, Ressourcen, Timeout, Deadlock
        }
        return .permanent
    }
}
