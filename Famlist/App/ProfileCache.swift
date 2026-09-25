/*
 ProfileCache.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lokale Kopie des eigenen Profils (je Nutzer-ID), damit die App ohne Netz startet.

 🔰 Notes for Beginners:
 - Vorher lud der Start das Profil immer vom Server; ohne Netz landete man auf „Anmelden“,
   obwohl alle Listen lokal gespeichert waren (Audit K6).
 - Beim Abmelden wird die Kopie gelöscht.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

enum ProfileCache {
    private static func key(_ userId: UUID) -> String { "famlist.profile.\(userId.uuidString)" }
    private static let prefix = "famlist.profile."

    static func load(userId: UUID, defaults: UserDefaults = .standard) -> Profile? {
        guard let data = defaults.data(forKey: key(userId)) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }

    static func save(_ profile: Profile, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key(profile.id))
    }

    static func clearAll(defaults: UserDefaults = .standard) {
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.forEach(defaults.removeObject(forKey:))
    }
}
