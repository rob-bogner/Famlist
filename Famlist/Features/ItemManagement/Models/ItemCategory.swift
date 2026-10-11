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
 - Von 8 auf 27 Kategorien erweitert (Wunsch Robert 12.10.2026; Quellen: Sortimente von Edeka24, Knuspr, myTime).
 - Initial creation (FAM-63, FAM-65)
 ------------------------------------------------------------------------
*/

import Foundation

/// Vordefinierte Produktkategorien für die Einkaufsliste.
/// Reihenfolge entspricht typischer Supermarkt-Laufreihenfolge.
enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case obstGemuese  = "Obst & Gemüse"
    case backwaren    = "Backwaren"
    case fleisch      = "Fleisch & Fisch"
    case wurst        = "Wurst & Aufschnitt"
    case kaese        = "Käse"
    case milch        = "Milchprodukte"
    case eier         = "Eier"
    case vegetarisch  = "Vegetarisch & Vegan"
    case fruehstueck  = "Frühstück & Aufstriche"
    case backzutaten  = "Backzutaten"
    case nudelnReis   = "Nudeln & Reis"
    case konserven    = "Konserven"
    case fertig       = "Fertiggerichte"
    case saucen       = "Saucen & Dips"
    case gewuerze     = "Öl, Essig & Gewürze"
    case kaffeeTee    = "Kaffee, Tee & Kakao"
    case suesses      = "Süßigkeiten"
    case snacks       = "Snacks & Knabbereien"
    case tiefkuehl    = "Tiefkühl"
    case getraenke    = "Getränke"
    case alkohol      = "Bier, Wein & Spirituosen"
    case drogerie     = "Drogerie"
    case haushalt     = "Haushalt"
    case baby         = "Baby & Kind"
    case tierbedarf   = "Tierbedarf"
    case blumen       = "Blumen & Pflanzen"
    case sonstiges    = "Sonstiges"

    var id: String { rawValue }

    /// SF Symbol für den Section Header und den Kategorie-Chip (nur außerhalb des Hybrid-Designs;
    /// das Hybrid-Design nutzt `svgIcon`). Die am 12.10.2026 ergänzten Kategorien haben kein eigenes Symbol.
    var icon: String {
        switch self {
        case .obstGemuese: return "leaf.fill"
        case .milch:       return "drop.fill"
        case .backwaren:   return "fork.knife"
        case .getraenke:   return "cup.and.saucer.fill"
        case .haushalt:    return "house.fill"
        case .tiefkuehl:   return "snowflake"
        case .fleisch:     return "flame.fill"
        default:           return "tag.fill"
        }
    }

    /// Gröbere Kategorie aus dem alten 8er-Satz, in der ein Artikel vor dem 12.10.2026 stand
    /// (z. B. Käse → Milchprodukte). nil, wenn es keine passende gab (der Artikel stand unter „Sonstiges“).
    var coarser: ItemCategory? {
        switch self {
        case .kaese, .eier:        return .milch
        case .wurst:               return .fleisch
        case .alkohol, .kaffeeTee: return .getraenke
        case .drogerie:            return .haushalt
        default:                   return nil
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
