/*
 ListSortSettings.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sortier-Einstellung einer Liste: Modus (Kategorie, Alphabetisch, Zuletzt hinzugefügt, Manuell)
   und der Schalter „Erledigte nach unten“.

 🔰 Notes for Beginners:
 - Die Einstellung gilt pro Liste und liegt nur auf diesem Gerät (UserDefaults, Schlüssel je Liste).
   Sie wird NICHT synchronisiert: Jedes Familienmitglied darf seine eigene Ansicht haben.
 - Standard wie im Design (SortMenu): „Nach Kategorie“ und „Erledigte nach unten“ an.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Dock „Sortieren“).
 ------------------------------------------------------------------------
 */

import Foundation

/// Per-list sort preference, persisted locally.
struct ListSortSettings: Codable, Equatable {
    var order: SortOrder
    var doneAtBottom: Bool

    static let `default` = ListSortSettings(order: .category, doneAtBottom: true)

    private static func key(_ listId: UUID) -> String { "listSortSettings.\(listId.uuidString)" }

    /// Liest die gespeicherte Einstellung oder den Standard.
    static func load(listId: UUID, defaults: UserDefaults = .standard) -> ListSortSettings {
        guard let data = defaults.data(forKey: key(listId)),
              let settings = try? JSONDecoder().decode(ListSortSettings.self, from: data) else { return .default }
        return settings
    }

    /// Speichert die Einstellung für genau diese Liste.
    func save(listId: UUID, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key(listId))
    }
}
