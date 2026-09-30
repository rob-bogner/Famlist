/*
 CategoryColor.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Farben der Kategorien: Palette mit 36 Farben (Kategorie bearbeiten → Farbe) und die Kachel-Optik
   (Liste, Kategorien verwalten, Kategorie-Menü).

 🔰 Notes for Beginners:
 - Raster 9 × 4: Spalten Rot, Orange, Gelb, Grün, Türkis, Blau, Indigo, Violett, Pink;
   Zeilen hell · kräftig · dunkel · gedeckt (Werte wie im Canvas, siehe PLAN.md).
 - Gespeichert wird der Hex-Wert. Ohne gespeicherte Farbe gilt eine Standardfarbe aus dem Namen
   (bekannte Kategorien fest, eigene Kategorien stabil aus der Zeile „kräftig“).
 - Kachel: Verlauf 150° von +22 % hell über die Farbe zu −22 % dunkel, weißes Icon, farbiger Schatten.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026: 30–40 Farben je Kategorie, auch in der Liste).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum CategoryColor {
    struct Swatch: Identifiable, Hashable {
        let hex: String
        let name: String
        var id: String { hex }
        var rgb: RGB { RGB(hex: hex) }
    }

    static let hueNames = ["Rot", "Orange", "Gelb", "Grün", "Türkis", "Blau", "Indigo", "Violett", "Pink"]
    static let levelNames = ["hell", "kräftig", "dunkel", "gedeckt"]
    private static let rows: [[String]] = [
        ["#E14751", "#E17F47", "#E1B347", "#47E17A", "#47E1DC", "#4799E1", "#475BE1", "#8F47E1", "#E1479E"],
        ["#C72933", "#C76329", "#C79729", "#29C75D", "#29C7C2", "#297DC7", "#293EC7", "#7329C7", "#C72982"],
        ["#8F242B", "#8F4B24", "#8F6F24", "#248F47", "#248F8B", "#245D8F", "#24328F", "#56248F", "#8F2460"],
        ["#8D5E61", "#8D6F5E", "#8D7F5E", "#5E8D6D", "#5E8D8B", "#5E778D", "#5E648D", "#745E8D", "#8D5E78"],
    ]

    /// Alle 36 Farben zeilenweise (hell, kräftig, dunkel, gedeckt).
    static let palette: [Swatch] = rows.enumerated().flatMap { level, row in
        row.enumerated().map { hue, hex in Swatch(hex: hex, name: "\(hueNames[hue]) \(levelNames[level])") }
    }
    static let columns = 9

    /// Standard für bekannte Kategorien (wie im Canvas).
    private static let defaults: [String: String] = [
        ItemCategory.obstGemuese.rawValue: "#29C75D",
        ItemCategory.milch.rawValue: "#4799E1",
        ItemCategory.backwaren.rawValue: "#8F6F24",
        ItemCategory.getraenke.rawValue: "#29C7C2",
        ItemCategory.haushalt.rawValue: "#8F47E1",
        ItemCategory.tiefkuehl.rawValue: "#475BE1",
        ItemCategory.fleisch.rawValue: "#C72933",
        ItemCategory.sonstiges.rawValue: "#5E8D8B",
    ]

    /// Farbe für eine neue Kategorie, solange der Nutzer keine wählt.
    static let newCategoryHex = "#297DC7"

    /// Standardfarbe aus dem Namen: bekannte Kategorien fest, sonst stabil aus der Zeile „kräftig“.
    static func defaultHex(forName name: String) -> String {
        if let known = defaults.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame }) { return known.value }
        let sum = name.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return rows[1][sum % columns]
    }

    /// Gespeicherte Farbe (gültiges #RRGGBB) oder Standardfarbe.
    static func hex(for category: CategoryDefinition) -> String {
        if let color = category.color, isValid(color) { return color.uppercased() }
        return defaultHex(forName: category.name)
    }

    static func rgb(for category: CategoryDefinition) -> RGB { RGB(hex: hex(for: category)) }

    static func isValid(_ hex: String) -> Bool {
        hex.count == 7 && hex.hasPrefix("#") && hex.dropFirst().allSatisfy(\.isHexDigit)
    }

    static func name(forHex hex: String) -> String {
        palette.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? "Eigene Farbe"
    }

    // MARK: - Kachel

    /// Verlauf 150°: +22 % Richtung Weiß → Farbe (55 %) → −22 % Richtung Schwarz.
    static func tilePaint(_ rgb: RGB) -> Paint {
        .linear(150, [stop(rgb.mix(toward: 255, 0.22).color(), 0), stop(rgb.color(), 0.55), stop(rgb.mix(toward: 0, 0.22).color(), 1)])
    }

    /// inset 0 1px 0 rgba(255,255,255,.4), 0 6px 14px -5px rgba(Farbe,.55)
    static func tileShadow(_ rgb: RGB) -> [BoxShadow] {
        [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.4)), .drop(0, 6, 14, -5, rgb.color(0.55))]
    }

    /// Weiche Kachel (Kategorie-Menü): Farbe 12 % (Dark 20 %), Icon in der Farbe.
    static func softFill(_ rgb: RGB, dark: Bool) -> Color { rgb.color(dark ? 0.2 : 0.12) }
}
