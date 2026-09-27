/*
 WatchWidgetState.swift
 FamlistWatch (auch FamlistWatchWidgets)
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kleiner Stand für Smart Stack und Komplikationen (Watch-Plan §6): aktive Liste, offene und alle Artikel.
   Die Uhr-App schreibt ihn in die App Group, die Widget-Erweiterung liest nur ihn (keine Netzabfrage).

 🔰 Notes for Beginners:
 - App Group `group.com.roxo.famlist.watch` (Entitlements beider Targets). Ohne gespeicherten Stand zeigen
   die Widgets den Platzhalter.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchWidgetState: Codable, Equatable, Sendable {
    var listName: String
    var open: Int
    var total: Int

    static let appGroup = "group.com.roxo.famlist.watch"
    static let storageKey = "watch.widgetState"
    /// Beispiel wie im Design (WatchFace.dc.html) – Vorschau und Platzhalter.
    static let placeholder = WatchWidgetState(listName: "My List", open: 4, total: 6)
    /// Ohne Anmeldung oder ohne Listen.
    static let empty = WatchWidgetState(listName: "Famlist", open: 0, total: 0)

    /// Anteil erledigt (0…1) für Ring und Balken.
    var fraction: Double { total == 0 ? 0 : Double(total - open) / Double(total) }

    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load(from defaults: UserDefaults?) -> WatchWidgetState? {
        guard let data = defaults?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WatchWidgetState.self, from: data)
    }

    func save(to defaults: UserDefaults?) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.storageKey)
    }
}
