/*
 CategoryDefinition.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine benutzerdefinierte Kategorie: Name, Icon-Schlüssel, Position im Ladenweg.

 🔰 Notes for Beginners:
 - Artikel speichern den Kategorie-NAMEN als Text (Spalte items.category). Darum müssen Umbenennen
   und Löschen die Artikel mit ändern (CategoryStore + ListViewModel.reassignCategory).
 - „Sonstiges“ ist die Standardkategorie und kann nicht gelöscht werden; unbekannte Namen landen dort.
 - Standard-Kategorien für neue Konten = die bisherigen 8 festen Kategorien in ihrer Reihenfolge.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

struct CategoryDefinition: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    /// Schlüssel in CategoryIconCatalog („leaf“, „drop“ …).
    var icon: String
    /// Reihenfolge im Ladenweg (0 = zuerst).
    var position: Int

    static let fallbackName = ItemCategory.sonstiges.rawValue

    var isFallback: Bool { name.caseInsensitiveCompare(Self.fallbackName) == .orderedSame }

    var svgIcon: [SVGElement] { CategoryIconCatalog.icon(for: icon) }

    /// Die bisherigen 8 festen Kategorien (ItemCategory.displayOrder) als Startwerte.
    static let defaults: [CategoryDefinition] = {
        ItemCategory.displayOrder.enumerated().map { index, category in
            CategoryDefinition(id: UUID(), name: category.rawValue,
                               icon: CategoryIconCatalog.key(for: category), position: index)
        }
    }()
}
