/*
 CatalogOperation.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Schreibauftrag an den Artikelstamm (Anlegen/Überschreiben, Ändern, Löschen, Zählen), der offline
   in der Warteschlange wartet, bis er an Supabase gesendet werden kann.

 🔰 Notes for Beginners:
 - `apply(to:)` spielt den Auftrag auf eine lokale Liste ab. So zeigt „Artikel verwalten“ offline
   schon den neuen Stand, obwohl der Server ihn noch nicht kennt.
 - `save` verhält sich wie das Upsert von Supabase: gleicher Name (ohne Groß/klein) → überschreiben.
   Der Zähler („Oft gekauft“) bleibt dabei erhalten; das Upsert schickt ihn nicht mit.
 - `noteUse` zählt wie die RPC catalog_note_use: +1 je Name, letzte Nutzung wandert nie zurück.

 📝 Last Change:
 - Auftrag noteUse (Zähler „Oft gekauft“, Migration 022, 26.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

enum CatalogOperation: Codable, Equatable {
    /// Upsert nach Besitzer + Name (Liste → Artikelstamm).
    case save(ItemCatalogEntry)
    /// Ändern über die ID (Artikel verwalten → Bearbeiten).
    case update(ItemCatalogEntry)
    /// Löschen über die ID (Artikel verwalten → Wischen).
    case delete(id: String)
    /// Hinzufügungen zählen (Liste → „Oft gekauft“); `at` = Zeitpunkt auf dem Gerät.
    case noteUse(names: [String], at: Date)

    /// Wendet den Auftrag auf `entries` an; Ergebnis alphabetisch wie `fetchAll()`.
    func apply(to entries: [ItemCatalogEntry]) -> [ItemCatalogEntry] {
        var result = entries
        switch self {
        case .save(let entry):
            let key = Self.key(entry.name)
            if let i = result.firstIndex(where: { Self.key($0.name) == key }) {
                var merged = entry
                merged.id = result[i].id                      // Server behält die bestehende Zeile
                merged.ownerPublicId = result[i].ownerPublicId
                merged.barcode = entry.barcode ?? result[i].barcode
                merged.useCount = result[i].useCount     // Upsert ändert den Zähler nicht
                merged.lastUsedAt = result[i].lastUsedAt
                result[i] = merged
            } else {
                result.append(entry)
            }
        case .update(let entry):
            if let i = result.firstIndex(where: { $0.id == entry.id }) {
                var updated = entry
                updated.useCount = result[i].useCount     // Ändern schickt den Zähler nicht mit
                updated.lastUsedAt = result[i].lastUsedAt
                result[i] = updated
            }
        case .delete(let id):
            result.removeAll { $0.id == id }
        case .noteUse(let names, let date):
            Self.countUses(names, at: date, in: &result)
        }
        return result.sorted { Self.key($0.name) < Self.key($1.name) }
    }

    /// +1 je Name (gleicher Name mehrfach = mehrfach); ohne Eintrag passiert nichts (wie der Server).
    private static func countUses(_ names: [String], at date: Date, in entries: inout [ItemCatalogEntry]) {
        let usedAt = min(date, Date())
        for name in names {
            guard let i = entries.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) else { continue }
            entries[i].useCount = (entries[i].useCount ?? 0) + 1
            entries[i].lastUsedAt = max(entries[i].lastUsedAt ?? usedAt, usedAt)
        }
    }

    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
