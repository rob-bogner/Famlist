/*
 CategoryIconCatalog.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icon-Schlüssel ↔ SVG-Pfade für Kategorien (gespeichert in categories.icon).

 🔰 Notes for Beginners:
 - `designChoices` ist das Raster in „Kategorie bearbeiten“ (5 × 2, Reihenfolge wie im Design,
   EKKCategory.iconChoices im Referenzcode).
 - Die Standard-Kategorien nutzen zusätzlich glass/home/snowflake/flame (bisherige Icons).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

enum CategoryIconCatalog {
    /// Raster in „Kategorie bearbeiten“ (Design: leaf, drop, cutlery, tag, bag, dropSmall, bowl, fruit, umbrella, cup).
    static let designChoices = ["leaf", "drop", "cutlery", "tag", "bag", "dropSmall", "bowl", "fruit", "umbrella", "cup"]

    static func icon(for key: String) -> [SVGElement] {
        switch key {
        case "leaf": return Icon.leaf
        case "drop": return Icon.drop
        case "cutlery": return Icon.cutlery
        case "tag": return EKKIcon.tag
        case "bag": return EKKIcon.bag
        case "dropSmall": return EKKIcon.dropSmall
        case "bowl": return EKKIcon.bowl
        case "fruit": return EKKIcon.fruit
        case "umbrella": return EKKIcon.umbrella
        case "cup": return EKKIcon.cup
        case "glass": return Icon.glass
        case "home": return Icon.home
        case "snowflake": return Icon.snowflake
        case "flame": return Icon.flame
        default: return EKKIcon.tag
        }
    }

    static func key(for category: ItemCategory) -> String {
        switch category {
        case .obstGemuese: return "leaf"
        case .milch: return "drop"
        case .backwaren: return "cutlery"
        case .getraenke: return "glass"
        case .haushalt: return "home"
        case .tiefkuehl: return "snowflake"
        case .fleisch: return "flame"
        case .sonstiges: return "tag"
        }
    }
}
