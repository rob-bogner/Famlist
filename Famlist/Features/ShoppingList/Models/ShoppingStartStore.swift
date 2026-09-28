/*
 ShoppingStartStore.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Merkt den Einkaufsbeginn „laut Liste“: den Zeitpunkt des ersten Abhakens in einer Liste.
   Daraus entstehen im Kassenzettel-Archiv Uhrzeit „ab“ und Dauer des Einkaufs.

 🔰 Notes for Beginners:
 - Nur lokal (UserDefaults je Liste), nicht synchronisiert: Es zählt, wann DIESES Gerät zu kaufen begann.
 - Ein neuer Beginn wird gemerkt, wenn noch keiner da ist oder der gemerkte älter als 4 Stunden ist
   (dann gehört er zu einem früheren Einkauf, der nie abgeschlossen wurde).
 - Zurückgesetzt nach „Preise speichern“ (der Bon hat ihn übernommen) und nach „Einkauf erledigt“.
 - `plausibleStart`: Beginn nach dem Ende oder mehr als 4 Stunden davor → verworfen.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum ShoppingStartStore {
    /// Länger dauert kein Einkauf; ältere Zeitpunkte gehören zu einem früheren Einkauf.
    static let maxDuration: TimeInterval = 4 * 3600

    private static func key(_ listId: UUID) -> String { "shoppingStartedAt.\(listId.uuidString)" }

    static func start(listId: UUID, defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: key(listId)) as? Date
    }

    /// Abhaken in der Liste: Beginn merken, wenn keiner da ist oder der gemerkte zu alt ist.
    static func noteCheck(listId: UUID, now: Date = Date(), defaults: UserDefaults = .standard) {
        if let known = start(listId: listId, defaults: defaults), now.timeIntervalSince(known) <= maxDuration,
           known <= now { return }
        defaults.set(now, forKey: key(listId))
    }

    static func reset(listId: UUID, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(listId))
    }

    /// Beginn nur, wenn er vor dem Ende liegt und der Einkauf höchstens 4 Stunden dauerte.
    static func plausibleStart(_ start: Date?, end: Date?) -> Date? {
        guard let start, let end else { return nil }
        let duration = end.timeIntervalSince(start)
        return duration >= 0 && duration <= maxDuration ? start : nil
    }
}
