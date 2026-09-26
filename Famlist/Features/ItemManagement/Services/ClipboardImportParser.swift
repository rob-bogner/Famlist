/*
 ClipboardImportParser.swift
 Created: 19.10.2025 | Updated: 25.09.2026

 Purpose: Mehrstufige Pipeline zum Parsen von Einkaufslisten aus der Zwischenablage.

 CHANGELOG:
 - 19.10.2025: Initial version
 - 14.03.2026: FAM-60 – Ranges, Brüche, Komma-Notizen, Klammer-Notizen
 - 14.03.2026: FAM-60 cont. – Robuste Pipeline-Architektur:
               führende Klammer-Mengen (2), Dezimalzahlen, kanonisches Measure-Mapping,
               nicht unterstützte Einheiten werden verworfen (nicht in Name übernommen)
 - 16.03.2026: FAM-71 – ParsedItem.stableId(forList:) via UUID.deterministicItemID
 - 25.09.2026: Audit-Fixes – erste Zeile nur bei eindeutigem Ladennamen als Laden,
               Multiplikatoren (2x / 2 x / x2 / 2×), Dezimalmengen in kleinere Einheit
               (1,5 kg → 1500 g, 0,5 l → 500 ml, 1,5 m → 150 cm, Stück aufgerundet),
               Aufzählungszeichen und Checkboxen am Zeilenanfang entfernt
 - 25.09.2026: Stufen in ClipboardImportParser+Lines/+Quantity/+Units.swift ausgelagert (Audit)
*/

import Foundation

/// Parst Clipboard-Text mit Einkaufslisten in strukturierte Artikel.
///
/// Pipeline pro Artikelzeile:
/// 1. `normalizeLine`                  – Whitespace, Komma-Normalisierung, Aufzählungszeichen weg
/// 2. `parseLeadingParenQuantity`      – `(2) Eier` → qty=2
/// 3. `parseLeadingMultiplier`         – `2x Milch`, `2 x Milch`, `x2 Milch`, `2× Milch` → qty=2
/// 4. `parseLeadingQuantityToken`      – Integer, Dezimal, Bruch, Bereich
/// 5. `consumeUnitTokens`              – Unterstützte Einheit speichern, nicht unterstützte verwerfen
/// 6. `parseSuffixQuantity`            – `Milch 1x`, `Milch x2` Fallback
/// 7. `extractNameAndNote`             – Komma- und Klammer-Notizen trennen
/// 8. `resolveUnits`                   – Dezimalmengen in kleinere Einheit bzw. aufrunden
///
/// Die erste Zeile ist nur dann der Ladenname, wenn sie eindeutig kein Artikel ist
/// (siehe `detectStoreName`).
struct ClipboardImportParser {

    // MARK: - Output Types

    struct ParsedItem {
        let name: String
        /// Ganzzahl-Menge, mind. 1. Dezimalmengen bei kg/l/m werden in g/ml/cm umgerechnet,
        /// alle anderen Dezimalmengen auf ganze Stück aufgerundet (siehe `resolveUnits`).
        let units: Int
        /// Kanonischer Measure-rawValue der App-Enum, oder "" wenn keine Einheit.
        let measure: String
        let category: String?
        let brand: String?          // Immer nil; API-Kompatibilität
        let productDescription: String?

        /// Gibt eine deterministische Item-ID zurück, die für gleichen Listenkontext
        /// und gleichen Artikelnamen stets identisch ist.
        ///
        /// Delegiert an `UUID.deterministicItemID(listId:name:)` – dieselbe Funktion,
        /// die der SyncEngine nutzt – damit IDs über alle Erstellungspfade konsistent sind.
        func stableId(forList listId: UUID) -> String {
            UUID.deterministicItemID(listId: listId, name: name).uuidString
        }
    }

    struct ParseResult {
        let items: [ParsedItem]
        let storeName: String?
        let skippedLines: [String]
    }

    // MARK: - Public API

    static func parse(_ text: String) -> ParseResult {
        let rawLines = text.components(separatedBy: .newlines).map { normalizeLine($0) }
        var lines = rawLines.filter { !$0.isEmpty }
        let storeName = detectStoreName(in: rawLines)
        if storeName != nil { lines.removeFirst() }

        var items: [ParsedItem] = []
        var currentCategory: String?
        var skippedLines: [String] = []

        for line in lines {
            if let category = parseCategoryLine(line) {
                currentCategory = category
                continue
            }
            if let parsed = parseItemLine(line, category: currentCategory) {
                items.append(parsed)
            } else {
                skippedLines.append(line)
            }
        }
        return ParseResult(items: items, storeName: storeName, skippedLines: skippedLines)
    }

    // MARK: - Artikel-Zeile (Haupt-Dispatcher)

    private static func parseItemLine(_ line: String, category: String?) -> ParsedItem? {
        guard !line.isEmpty else { return nil }

        let parsed = parseQuantity(line)

        // Stage 4: Name / Notiz trennen
        let (name, note) = extractNameAndNote(parsed.remaining)
        // Trennlinien wie „---“, „***“ oder „===“ sind keine Artikel: Ein Name braucht mindestens einen Buchstaben.
        guard name.unicodeScalars.contains(where: CharacterSet.letters.contains) else { return nil }

        let (units, measure) = parsed.explicit
            ? resolveUnits(parsed.quantity, measure: parsed.measure)
            : (1, parsed.measure)

        return ParsedItem(
            name:               name,
            units:              units,
            measure:            measure,
            category:           category,
            brand:              nil,
            productDescription: note
        )
    }

    /// Zwischenergebnis der Mengen-Erkennung.
    private struct QuantityParse {
        var quantity: Double = 1
        var measure = ""
        var explicit = false
        var remaining: String
    }

    /// Stage 3: Menge und Einheit am Anfang (oder als Suffix) erkennen.
    private static func parseQuantity(_ text: String) -> QuantityParse {
        // 3a: Führende Klammer-Menge – "(2) Eier". Danach wird KEINE Einheit geparst.
        if let paren = parseLeadingParenQuantity(text) {
            return QuantityParse(quantity: paren.quantity, explicit: true, remaining: paren.remaining)
        }
        // 3b: Multiplikator – "2x Milch", "x2 Milch". Menge in Stück, keine Einheit.
        if let mult = parseLeadingMultiplier(text) {
            return QuantityParse(quantity: mult.quantity, explicit: true, remaining: mult.remaining)
        }
        // 3c: Numerische führende Menge + Einheiten-Konsum
        if let q = parseLeadingQuantityToken(text) {
            let (m, rest, hadUnsupported) = consumeUnitTokens(from: q.remaining)
            // Menge gehörte zu einer nicht unterstützten Einheit (EL, TL, Schuss …) →
            // Menge verwerfen; nur den bereinigten Artikelnamen übernehmen.
            if hadUnsupported { return QuantityParse(remaining: rest) }
            return QuantityParse(quantity: q.quantity, measure: m, explicit: true, remaining: rest)
        }
        // 3d: Trailing-Suffix "Milch 1x" / "Milch x2"
        if let suffix = parseSuffixQuantity(text) {
            return QuantityParse(quantity: Double(suffix.units), explicit: true, remaining: suffix.remaining)
        }
        // 3e: Nachgestellte Menge mit bekannter Einheit – "Milch 2 l", "Ritter Sport 100 g", "Eier 10 Stk".
        if let trailing = parseTrailingUnitQuantity(text) {
            return QuantityParse(quantity: trailing.quantity, measure: trailing.measure, explicit: true,
                                 remaining: trailing.remaining)
        }
        return QuantityParse(remaining: text)
    }
}
