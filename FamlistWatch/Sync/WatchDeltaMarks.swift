/*
 WatchDeltaMarks.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeitmarke der Delta-Abfrage aller Listen und die Listen, für die sie gilt (UserDefaults der Uhr).

 🔰 Notes for Beginners:
 - Eine gemeinsame Zeitmarke für alle bekannten Listen. Neu hinzugekommene Listen (geteilt, neu angelegt)
   fragt die Uhr einmal komplett ab (seit `.distantPast`) und nimmt sie danach in die Menge auf.
 - Die Marke rückt erst vor, wenn die Zeilen gespeichert sind (wie auf dem iPhone).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
struct WatchDeltaMarks {
    private let defaults: UserDefaults
    static let sinceKey = "watch.delta.since"
    static let listsKey = "watch.delta.lists"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Neuester übernommener Server-Zeitstempel (Date.distantPast = noch nie abgefragt).
    var since: Date {
        get {
            defaults.string(forKey: Self.sinceKey).flatMap(PaginationCursor.postgrestFormatter.date(from:)) ?? .distantPast
        }
        nonmutating set {
            defaults.set(PaginationCursor.postgrestFormatter.string(from: newValue), forKey: Self.sinceKey)
        }
    }

    /// Listen, die in `since` bereits enthalten sind.
    var knownLists: Set<UUID> {
        get { Set((defaults.stringArray(forKey: Self.listsKey) ?? []).compactMap(UUID.init(uuidString:))) }
        nonmutating set { defaults.set(newValue.map(\.uuidString).sorted(), forKey: Self.listsKey) }
    }

    /// Beginn des Abfragefensters: 5 s Überlappung wie auf dem iPhone (verspätet sichtbare Transaktionen);
    /// doppelte Zeilen verwirft die HLC-Regel.
    var windowStart: Date {
        let mark = since
        return mark == .distantPast ? mark : mark.addingTimeInterval(-5)
    }

    func clear() {
        defaults.removeObject(forKey: Self.sinceKey)
        defaults.removeObject(forKey: Self.listsKey)
    }
}
