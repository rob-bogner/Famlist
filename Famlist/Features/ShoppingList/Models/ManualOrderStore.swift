/*
 ManualOrderStore.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Speichert die manuelle Reihenfolge („Manuell – Per Ziehen anordnen“) einer Liste als
   geordnete Artikel-IDs.

 🔰 Notes for Beginners:
 - Nur lokal (UserDefaults je Liste), nicht synchronisiert. Gleichzeitiges Ziehen auf zwei Geräten
   würde sonst widersprüchliche Positionen erzeugen (siehe design-handoff/PLAN.md).
 - Neue Artikel, die noch nicht in der Reihenfolge stehen, erscheinen hinter den angeordneten.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import Foundation

/// Local, per-list manual item order.
enum ManualOrderStore {
    private static func key(_ listId: UUID) -> String { "manualItemOrder.\(listId.uuidString)" }

    static func load(listId: UUID, defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key(listId)) ?? []
    }

    static func save(_ ids: [String], listId: UUID, defaults: UserDefaults = .standard) {
        defaults.set(ids, forKey: key(listId))
    }
}
