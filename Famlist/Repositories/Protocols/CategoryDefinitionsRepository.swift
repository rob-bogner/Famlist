/*
 CategoryDefinitionsRepository.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Speichert die Kategorien des Nutzers (Name, Icon, Position) in der Tabelle `categories` (Migration 011).

 🔰 Notes for Beginners:
 - RLS begrenzt Lesen und Schreiben auf profile_id = auth.uid().
 - Ersetzt das alte, nie verdrahtete CategoriesRepository (Emoji/Farbe).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

protocol CategoryDefinitionsRepository {
    /// Eigene Kategorien, nach Position sortiert.
    func fetch(profileId: UUID) async throws -> [CategoryDefinition]
    /// Legt an oder ändert (Name, Icon, Position) – mehrere auf einmal (z. B. nach dem Umsortieren).
    func upsert(_ categories: [CategoryDefinition], profileId: UUID) async throws
    func delete(id: UUID) async throws
}

/// Für Vorschauen und Tests: hält alles im Speicher.
final class InMemoryCategoryDefinitionsRepository: CategoryDefinitionsRepository {
    private(set) var stored: [CategoryDefinition]

    init(_ stored: [CategoryDefinition] = []) { self.stored = stored }

    func fetch(profileId: UUID) async throws -> [CategoryDefinition] { stored.sorted { $0.position < $1.position } }

    func upsert(_ categories: [CategoryDefinition], profileId: UUID) async throws {
        for c in categories {
            if let i = stored.firstIndex(where: { $0.id == c.id }) { stored[i] = c } else { stored.append(c) }
        }
    }

    func delete(id: UUID) async throws { stored.removeAll { $0.id == id } }
}
