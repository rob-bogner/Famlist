/*
 WatchMessage.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nachrichten zwischen iPhone und Apple Watch (WatchConnectivity), geteilt von beiden Targets.

 🛠 Includes:
 - requestSession / sessionGrant / sessionUnavailable: Anmeldung der Uhr über das iPhone (Edge Function
   watch-session, Watch-Plan §2).
 - itemsChanged: Sofort-Weg für geänderte Artikel (ohne Fotos). Der Empfänger übernimmt sie NUR per HLC
   (mergeRemote) und sendet sie nicht erneut an den Server.
 - signedOut: Abmelden/Kontowechsel auf dem iPhone (garantierter Weg transferUserInfo).

 🔰 Notes for Beginners:
 - WatchConnectivity transportiert nur Property-List-Werte. Die Nachricht steht deshalb als JSON-Daten
   unter dem Schlüssel „m“, daneben die Version „v“. Eine unbekannte Version wird abgelehnt, statt
   halb verstanden zu werden.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

enum WatchMessage: Codable, Equatable, Sendable {
    /// Uhr → iPhone: „Bitte einen Anmelde-Code“ (Antwort: sessionGrant oder sessionUnavailable).
    case requestSession
    /// iPhone → Uhr: Code für verifyOTP(tokenHash:type: .magiclink) und das Konto, zu dem er gehört.
    case sessionGrant(tokenHash: String, userId: UUID)
    /// iPhone → Uhr: kein Code (Grund: `Reason`).
    case sessionUnavailable(reason: Reason)
    /// Beide Richtungen: geänderte Artikel (Fotos entfernt).
    case itemsChanged([ItemModel])
    /// iPhone → Uhr: abgemeldet oder Konto gewechselt – Uhr meldet sich ab und leert ihren Speicher.
    case signedOut

    enum Reason: String, Codable, Sendable {
        /// iPhone ist selbst nicht angemeldet.
        case signedOut
        /// Letzter Code liegt weniger als 10 s zurück (Migration 023).
        case rateLimited
        /// Netz- oder Serverfehler; später erneut versuchen.
        case failed
    }

    /// Version des Formats. Erhöhen, sobald sich die Bedeutung eines Falls ändert.
    static let version = 1
    /// Artikel je Nachricht (WatchConnectivity begrenzt die Größe einer Nachricht).
    static let maxItemsPerMessage = 50

    enum CodingError: Error, Equatable {
        case unsupportedVersion(Int)
        case malformed
    }

    // MARK: - Property-List-Form

    func dictionary() throws -> [String: Any] {
        ["v": Self.version, "m": try JSONEncoder().encode(self)]
    }

    init(dictionary: [String: Any]) throws {
        let version = dictionary["v"] as? Int ?? 0
        guard version == Self.version else { throw CodingError.unsupportedVersion(version) }
        guard let data = dictionary["m"] as? Data else { throw CodingError.malformed }
        self = try JSONDecoder().decode(WatchMessage.self, from: data)
    }

    /// Artikel für den Sofort-Weg: ohne Fotos (Base64), aufgeteilt in Nachrichten passender Größe.
    static func itemBatches(_ items: [ItemModel]) -> [WatchMessage] {
        let slim = items.map { item -> ItemModel in
            var copy = item
            copy.imageData = nil
            return copy
        }
        return stride(from: 0, to: slim.count, by: maxItemsPerMessage).map {
            .itemsChanged(Array(slim[$0..<min($0 + maxItemsPerMessage, slim.count)]))
        }
    }
}
