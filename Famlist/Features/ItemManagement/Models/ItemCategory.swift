/*
 ItemCategory.swift

 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vordefinierte Einkaufskategorien in Supermarkt-Reihenfolge.
 - Ermöglicht typsichere Kategoriezuweisung bei gleichzeitiger String-Persistenz
   für Rückwärtskompatibilität mit bestehenden Daten.

 🛠 Includes:
 - ItemCategory Enum mit SF Symbols und Display-Namen
 - Fallback-Initialisierung aus freiem String (nil → .sonstiges)

 📝 Last Change:
 - Initial creation (FAM-63, FAM-65)
 ------------------------------------------------------------------------
*/

import Foundation

/// Vordefinierte Produktkategorien für die Einkaufsliste.
/// Reihenfolge entspricht typischer Supermarkt-Laufreihenfolge.
enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case obstGemuese  = "Obst & Gemüse"
    case milch        = "Milchprodukte"
    case backwaren    = "Backwaren"
    case getraenke    = "Getränke"
    case haushalt     = "Haushalt"
    case tiefkuehl    = "Tiefkühl"
    case fleisch      = "Fleisch & Fisch"
    case sonstiges    = "Sonstiges"

    var id: String { rawValue }

    /// SF Symbol für den Section Header und den Kategorie-Chip.
    var icon: String {
        switch self {
        case .obstGemuese: return "leaf.fill"
        case .milch:       return "drop.fill"
        case .backwaren:   return "fork.knife"
        case .getraenke:   return "cup.and.saucer.fill"
        case .haushalt:    return "house.fill"
        case .tiefkuehl:   return "snowflake"
        case .fleisch:     return "flame.fill"
        case .sonstiges:   return "tag.fill"
        }
    }

    /// Anzeigereihenfolge in der ListView (entspricht Enum-Reihenfolge).
    static var displayOrder: [ItemCategory] { allCases }

    /// Initialisiert aus einem freien String (z. B. aus bestehenden SwiftData-Einträgen).
    /// Unbekannte oder leere Werte fallen auf `.sonstiges` zurück.
    static func from(_ string: String?) -> ItemCategory {
        guard let s = string, !s.isEmpty else { return .sonstiges }
        return allCases.first { $0.rawValue == s } ?? .sonstiges
    }
}
