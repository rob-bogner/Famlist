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
 - Standard-Kategorien für neue Konten = die 27 festen Kategorien (ItemCategory) in ihrer Reihenfolge.
   Bestehende Konten haben die 19 neuen über Migration 040 bekommen.

 📝 Last Change:
 - 27 statt 8 Standard-Kategorien; `standard(_:)` für Vorschauen und Tests (12.10.2026).
 - Feld `color` (#RRGGBB, optional; Migration 033) (30.09.2026).
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
    /// Farbe (#RRGGBB) aus der Palette „Kategorie bearbeiten → Farbe“. nil = Standardfarbe (CategoryColor).
    var color: String? = nil

    static let fallbackName = ItemCategory.sonstiges.rawValue

    var isFallback: Bool { name.caseInsensitiveCompare(Self.fallbackName) == .orderedSame }

    var svgIcon: [SVGElement] { CategoryIconCatalog.icon(for: CategoryIconCatalog.displayKey(name: name, icon: icon)) }

    /// Die festen Kategorien (ItemCategory.displayOrder) als Startwerte.
    static let defaults: [CategoryDefinition] = {
        ItemCategory.displayOrder.enumerated().map { index, category in
            CategoryDefinition(id: UUID(), name: category.rawValue,
                               icon: CategoryIconCatalog.key(for: category), position: index)
        }
    }()

    /// Startwert einer festen Kategorie (Vorschauen und Tests greifen so nicht über die Position zu).
    static func standard(_ category: ItemCategory) -> CategoryDefinition {
        defaults.first { $0.name == category.rawValue } ?? defaults[defaults.count - 1]
    }
}
