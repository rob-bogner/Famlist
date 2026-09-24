/*
 CatalogOperation.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Schreibauftrag an den Artikelstamm (Anlegen/Überschreiben, Ändern, Löschen), der offline
   in der Warteschlange wartet, bis er an Supabase gesendet werden kann.

 🔰 Notes for Beginners:
 - `apply(to:)` spielt den Auftrag auf eine lokale Liste ab. So zeigt „Artikel verwalten“ offline
   schon den neuen Stand, obwohl der Server ihn noch nicht kennt.
 - `save` verhält sich wie das Upsert von Supabase: gleicher Name (ohne Groß/klein) → überschreiben.

 📝 Last Change:
 - Initial creation (Artikelstamm offline zuerst).
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
                result[i] = merged
            } else {
                result.append(entry)
            }
        case .update(let entry):
            if let i = result.firstIndex(where: { $0.id == entry.id }) { result[i] = entry }
        case .delete(let id):
            result.removeAll { $0.id == id }
        }
        return result.sorted { Self.key($0.name) < Self.key($1.name) }
    }

    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
