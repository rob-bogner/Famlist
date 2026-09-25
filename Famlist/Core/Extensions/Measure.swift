/*
 Measure.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengeneinheiten der App (gespeichert als rawValue-String), mit Übersetzung und Normalisierung.

 📝 Last Change:
 - Aus ViewModifiers.swift ausgelagert; die übrigen Alt-Bausteine dort waren ungenutzt (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum Measure: String, CaseIterable, Codable { // Supported measurement units
    case item, cup, bag, bunch, can, bottle, jar, carton, crate, box, net, pair, pack, sack, slice, piece, bar, tube, smallBag, g, kg, ml, l, cm, m // All unit cases

    var localizationKey: String { // Localization key for each unit
        switch self { // Switch over unit to choose localization key
        case .item: return "unit.item"
        case .cup: return "unit.cup"
        case .bag: return "unit.bag"
        case .bunch: return "unit.bunch"
        case .can: return "unit.can"
        case .bottle: return "unit.bottle"
        case .jar: return "unit.jar"
        case .carton: return "unit.carton"
        case .crate: return "unit.crate"
        case .box: return "unit.box"
        case .net: return "unit.net"
        case .pair: return "unit.pair"
        case .pack: return "unit.pack"
        case .sack: return "unit.sack"
        case .slice: return "unit.slice"
        case .piece: return "unit.piece"
        case .bar: return "unit.bar"
        case .tube: return "unit.tube"
        case .smallBag: return "unit.bagSmall"
        case .g: return "unit.g"
        case .kg: return "unit.kg"
        case .ml: return "unit.ml"
        case .l: return "unit.l"
        case .cm: return "unit.cm"
        case .m: return "unit.m"
        }
    }

    var localizedName: String { // Localized human-readable name for display
        let fallback: String // Fallback english-ish label
        switch self { // Determine fallback text based on unit
        case .g, .kg, .ml, .l, .cm, .m: fallback = rawValue // Use raw for metric
        case .smallBag: fallback = "Small Bag" // Custom capitalization
        default: fallback = String(describing: self).capitalized // Generic capitalization
        }
        let translated = NSLocalizedString(localizationKey, comment: "Measurement Unit") // Lookup localization
        return translated == localizationKey ? fallback : translated // Use fallback when missing
    }

    static func fromExternal(_ raw: String) -> Measure { // Normalizes free-form input to a known case
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() // Normalize spacing/case
        switch lower { // Map common synonyms
        case "piece", "item": return .piece
        case "cup": return .cup
        case "bag": return .bag
        case "bunch": return .bunch
        case "can": return .can
        case "bottle": return .bottle
        case "jar": return .jar
        case "carton": return .carton
        case "crate": return .crate
        case "box": return .box
        case "net": return .net
        case "pair": return .pair
        case "pack": return .pack
        case "sack": return .sack
        case "slice": return .slice
        case "bar": return .bar
        case "tube": return .tube
        case "smallbag", "bag_small": return .smallBag
        case "g": return .g
        case "kg": return .kg
        case "ml": return .ml
        case "l": return .l
        case "cm": return .cm
        case "m": return .m
        default: return Measure(rawValue: lower) ?? .piece // Fall back to piece
        }
    }
}
