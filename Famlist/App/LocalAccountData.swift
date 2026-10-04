/*
 LocalAccountData.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Entfernt beim Abmelden die lokalen Einstellungen, die an Listen des Kontos hängen
   (Sortierung, manuelle Reihenfolge, Zeitmarken und Cursor des Abgleichs, Kategorien-Kopie).

 🔰 Notes for Beginners:
 - Geräte-Einstellungen (Erscheinungsbild, Preise anzeigen, HLC-Geräte-ID) bleiben erhalten.

 📝 Last Change:
 - Merker für das Konto einer abgelaufenen Anmeldung (04.10.2026).
 - Initial creation (Audit 25.09.2026, Abmelden räumt auf).
 ------------------------------------------------------------------------
 */

import Foundation

enum LocalAccountData {
    /// Schlüssel-Präfixe der kontobezogenen Einträge in UserDefaults.
    static let prefixes = [
        "listSortSettings.",
        "manualItemOrder.",
        "fam24_last_sync_ts_",
        "fam24_last_reconcile_",
        "fam24_pagination_cursor_",
        "categoryDefinitions."
    ]

    /// Konto, dessen Anmeldung abgelaufen ist, während seine Daten auf dem Gerät blieben.
    /// Meldet sich danach ein anderes Konto an, werden diese Daten zuerst gelöscht.
    static let expiredSessionUserIdKey = "famlist.expiredSessionUserId"

    static func expiredSessionUserId(defaults: UserDefaults = .standard) -> UUID? {
        defaults.string(forKey: expiredSessionUserIdKey).flatMap(UUID.init(uuidString:))
    }

    static func setExpiredSessionUserId(_ id: UUID?, defaults: UserDefaults = .standard) {
        defaults.set(id?.uuidString, forKey: expiredSessionUserIdKey)
    }

    static func removeListPreferences(defaults: UserDefaults = .standard) {
        defaults.dictionaryRepresentation().keys
            .filter { key in prefixes.contains { key.hasPrefix($0) } }
            .forEach(defaults.removeObject(forKey:))
    }
}
