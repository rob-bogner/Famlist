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
        "fam24_pagination_cursor_",
        "categoryDefinitions."
    ]

    static func removeListPreferences(defaults: UserDefaults = .standard) {
        defaults.dictionaryRepresentation().keys
            .filter { key in prefixes.contains { key.hasPrefix($0) } }
            .forEach(defaults.removeObject(forKey:))
    }
}
