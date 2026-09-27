/*
 WatchApplicationContext.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Letzter Stand des iPhones für die Uhr (updateApplicationContext): angemeldetes Konto und Listen mit
   Änderungen. Jede neue Fassung ersetzt die vorige; die Uhr liest sie beim nächsten Aufwachen.

 🔰 Notes for Beginners:
 - `userId == nil` heißt: Das iPhone ist abgemeldet. Die Uhr meldet sich dann ebenfalls ab.
 - `changedListIds` ist nur ein Hinweis („zuerst diese Listen abfragen“), keine Daten.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchApplicationContext: Codable, Equatable, Sendable {
    var userId: UUID?
    var changedListIds: [UUID] = []
    var updatedAt = Date()

    func dictionary() throws -> [String: Any] {
        ["v": WatchMessage.version, "c": try JSONEncoder().encode(self)]
    }

    /// nil bei leerem Kontext (iPhone hat noch nie gesendet) oder unbekannter Version.
    init?(dictionary: [String: Any]) {
        guard dictionary["v"] as? Int == WatchMessage.version, let data = dictionary["c"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchApplicationContext.self, from: data) else { return nil }
        self = decoded
    }

    init(userId: UUID?, changedListIds: [UUID] = [], updatedAt: Date = Date()) {
        self.userId = userId
        self.changedListIds = changedListIds
        self.updatedAt = updatedAt
    }
}
