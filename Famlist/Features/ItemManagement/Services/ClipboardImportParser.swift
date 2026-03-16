/*
 ClipboardImportParser.swift
 Created: 19.10.2025 | Updated: 16.03.2026

 Purpose: Mehrstufige Pipeline zum Parsen von Einkaufslisten aus der Zwischenablage.

 CHANGELOG:
 - 19.10.2025: Initial version
 - 14.03.2026: FAM-60 – Ranges, Brüche, Komma-Notizen, Klammer-Notizen
 - 14.03.2026: FAM-60 cont. – Robuste Pipeline-Architektur:
               führende Klammer-Mengen (2), Dezimalzahlen, kanonisches Measure-Mapping,
               nicht unterstützte Einheiten werden verworfen (nicht in Name übernommen)
 - 16.03.2026: FAM-71 – ParsedItem.stableId(forList:) via UUID.deterministicItemID
*/

import Foundation

/// Parst Clipboard-Text mit Einkaufslisten in strukturierte Artikel.
///
/// Pipeline pro Artikelzeile:
/// 1. `normalizeLine`                  – Whitespace, Komma-Normalisierung
/// 2. `parseLeadingParenQuantity`      – `(2) Eier` → qty=2
/// 3. `parseLeadingQuantityToken`      – Integer, Dezimal, Bruch, Bereich
/// 4. `consumeUnitTokens`              – Unterstützte Einheit speichern, nicht unterstützte verwerfen
/// 5. `parseSuffixQuantity`            – `Milch 1x` Fallback
/// 6. `extractNameAndNote`             – Komma- und Klammer-Notizen trennen
struct ClipboardImportParser {

    // MARK: - Output Types

    struct ParsedItem {
        let name: String
        /// Ganzzahl-Menge, mind. 1. Dezimal/Bruch werden auf Int(qty) gerundet.
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

    // MARK: - Einheiten-Definitionen

    /// Mappe: lowercase Alias → kanonischer Measure-rawValue (nur App-unterstützte Einheiten).
    private static let supportedUnitsMap: [String: String] = [
        // Gewicht
        "g": "g", "gramm": "g", "gram": "g",
        "kg": "kg", "kilogramm": "kg", "kilogram": "kg", "kilo": "kg",
        // Volumen
        "ml": "ml", "milliliter": "ml", "millilitre": "ml",
        "l": "l", "liter": "l",
        // Länge (in Measure-Enum vorhanden)
        "m": "m", "meter": "m",
        // Verpackungstypen
        "stück": "piece", "stücke": "piece", "stk": "piece", "stk.": "piece",
        "packung": "pack", "packungen": "pack", "pck": "pack", "pck.": "pack",
        "dose": "can",     "dosen": "can",
        "flasche": "bottle", "flaschen": "bottle",
        "glas": "jar",     "gläser": "jar",
        "bund": "bunch",   "bünde": "bunch",
        "karton": "carton","kartons": "carton",
        "box": "box",      "boxen": "box",
        "netz": "net",     "netze": "net",
        "paar": "pair",    "paare": "pair",
        "sack": "sack",    "säcke": "sack",
        "tüte": "bag",     "tüten": "bag",
        "riegel": "bar",
        "tube": "tube",    "tuben": "tube",
        "kiste": "crate",  "kisten": "crate",
        "beutel": "smallBag",
    ]

    /// Bekannte, aber NICHT von der App unterstützte Einheiten-Tokens (lowercase).
    /// Diese werden beim Parsing still verworfen – sie landen weder im measure noch im Namen.
    private static let knownUnsupportedTokens: Set<String> = [
        "el", "tl",
        "schuss", "prise",
        "scheibe", "scheiben", "scheibe/n",
        "becher",
        "zehe", "zehen",
        "litres", "litre",
        "cm", "zentimeter",
        "cl", "dl",
        "pak", "x",
    ]

    /// Kombinierte, nach Länge absteigend sortierte Liste aller bekannten Einheiten-Tokens.
    /// Längere Tokens zuerst verhindert, dass "m" vor "ml" oder "litres" vor "l" greift.
    private static let sortedAllKnownUnits: [(token: String, canonical: String?)] = {
        var result: [(String, String?)] = []
        for (key, value) in supportedUnitsMap    { result.append((key, value)) }
        for key in knownUnsupportedTokens        { result.append((key, nil)) }
        return result.sorted { $0.0.count > $1.0.count }
    }()

    // MARK: - Public API

    static func parse(_ text: String) -> ParseResult {
        let lines = text.components(separatedBy: .newlines)
            .map { normalizeLine($0) }
            .filter { !$0.isEmpty }

        var items: [ParsedItem] = []
        var currentCategory: String?
        var storeName: String?
        var skippedLines: [String] = []

        for (index, line) in lines.enumerated() {
            if index == 0, !line.hasPrefix("[") {
                storeName = line
                continue
            }
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

    // MARK: - Stage 1: Normalisierung

    private static func normalizeLine(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: #"\s{2,}"#,  with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+,"#,    with: ",", options: .regularExpression)
        return s
    }

    // MARK: - Stage 2: Kategorie-Erkennung

    private static func parseCategoryLine(_ line: String) -> String? {
        guard line.hasPrefix("["), line.hasSuffix("]") else { return nil }
        return String(line.dropFirst().dropLast())
    }

    // MARK: - Artikel-Zeile (Haupt-Dispatcher)

    private static func parseItemLine(_ line: String, category: String?) -> ParsedItem? {
        guard !line.isEmpty else { return nil }

        var remainingText = line
        var quantity: Double = 1.0
        var measure = ""
        var quantityExplicit = false

        // Stage 3a: Führende Klammer-Menge – "(2) Eier"
        //           Nach Klammer-Menge wird KEINE weitere Einheit geparst.
        if let paren = parseLeadingParenQuantity(remainingText) {
            quantity        = paren.quantity
            remainingText   = paren.remaining
            quantityExplicit = true

        // Stage 3b: Numerische führende Menge + Einheiten-Konsum
        } else if let q = parseLeadingQuantityToken(remainingText) {
            let (m, rest, hadUnsupported) = consumeUnitTokens(from: q.remaining)
            if hadUnsupported {
                // Menge gehörte zu einer nicht unterstützten Einheit (EL, TL, Schuss …) →
                // Menge verwerfen; nur den bereinigten Artikelnamen übernehmen.
                remainingText = rest
            } else {
                quantity         = q.quantity
                quantityExplicit = true
                measure          = m
                remainingText    = rest
            }

        // Stage 3c: Trailing-Suffix "Milch 1x"
        } else if let suffix = parseSuffixQuantity(remainingText) {
            quantity        = Double(suffix.units)
            quantityExplicit = true
            remainingText   = suffix.remaining
        }

        // Stage 4: Name / Notiz trennen
        let (name, note) = extractNameAndNote(remainingText)
        guard !name.isEmpty else { return nil }

        // Fallback: explizite Menge ohne erkannte Einheit → "piece"
        if quantityExplicit && measure.isEmpty {
            measure = "piece"
        }

        return ParsedItem(
            name:               name,
            units:              quantityExplicit ? quantityToUnits(quantity) : 1,
            measure:            measure,
            category:           category,
            brand:              nil,
            productDescription: note
        )
    }

    // MARK: - Stage 3a: Führende Klammer-Menge

    /// `(2) Eier` → qty=2, remaining="Eier"
    /// `(2) 2-3 Frühlingszwiebeln` → qty=2, remaining="2-3 Frühlingszwiebeln"
    ///
    /// Nur reine Ganzzahlen in den Klammern werden akzeptiert;
    /// `(Jasmin 1:1,3)` wird NICHT gematcht.
    private static func parseLeadingParenQuantity(
        _ text: String
    ) -> (quantity: Double, remaining: String)? {
        let pattern = #"^\((\d+)\)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match    = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numRange  = Range(match.range(at: 1), in: text),
              let restRange = Range(match.range(at: 2), in: text)
        else { return nil }
        return (Double(text[numRange]) ?? 1, String(text[restRange]))
    }

    // MARK: - Stage 3b: Numerische führende Menge

    /// Parst die führende Zahl einer Artikelzeile.
    ///
    /// Unterstützte Formate:
    /// - Integer:          `250 g Hähnchen`    → qty=250
    /// - Dezimal (Komma):  `1,08 litres Brühe` → qty=1.08
    /// - Dezimal (Punkt):  `1.5 kg Kartoffeln` → qty=1.5
    /// - Bruch:            `1/2 TL Ingwer`     → qty=0.5
    /// - Bereich:          `2-3 Zwiebeln`      → qty=3 (obere Grenze)
    /// - Direkt angehängt: `140g Reis`         → qty=140, remaining="g Reis"
    private static func parseLeadingQuantityToken(
        _ text: String
    ) -> (quantity: Double, remaining: String)? {
        let pattern = #"^(\d+(?:[,.]\d+|[/]\d+|[-–]\d+)?)\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numRange = Range(match.range(at: 1), in: text)
        else { return nil }

        let quantity  = parseQuantityString(String(text[numRange]))
        let afterIdx  = text.index(text.startIndex, offsetBy: match.range.length)
        let remaining = String(text[afterIdx...])

        // Bare-Zahl ohne Rest (z. B. eine Zeile, die nur "5" ist) nicht als Menge werten
        guard !remaining.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return (quantity, remaining)
    }

    /// Wandelt einen Mengen-String in einen `Double` um.
    ///
    /// - `"1/2"`  → 0.5    (Bruch)
    /// - `"2-3"`  → 3.0    (Bereich, obere Grenze)
    /// - `"1,08"` → 1.08   (deutsches Dezimalkomma)
    /// - `"250"`  → 250.0
    private static func parseQuantityString(_ s: String) -> Double {
        if let slashIdx = s.firstIndex(of: "/") {
            let num = Double(String(s[..<slashIdx])) ?? 1
            let den = Double(String(s[s.index(after: slashIdx)...])) ?? 1
            return den > 0 ? num / den : 1
        }
        if let dashIdx = s.firstIndex(where: { $0 == "-" || $0 == "–" }) {
            return Double(String(s[s.index(after: dashIdx)...])) ?? 1
        }
        return Double(s.replacingOccurrences(of: ",", with: ".")) ?? 1
    }

    // MARK: - Stage 3b: Einheiten-Konsum

    /// Konsumiert führende bekannte Einheiten-Tokens gierig.
    ///
    /// - Unterstützte Einheit gefunden → als `measure` speichern, danach stoppen.
    /// - Nicht unterstützte Einheit gefunden → still verwerfen, weiter suchen.
    /// - Unbekanntes Wort → stoppen; dieses Wort ist der Beginn des Artikelnamens.
    ///
    /// Rückgabe `hadUnsupportedToken`: true wenn mindestens ein nicht unterstütztes Token
    /// konsumiert wurde und keine unterstützte Einheit gefunden wurde. Wird in `parseItemLine`
    /// genutzt, um die Mengenangabe bei reinen Küchen-Einheiten (EL, TL, Schuss …) zu verwerfen.
    ///
    /// Beispiele:
    /// - `"g Hähnchen"` → measure="g", remaining="Hähnchen", hadUnsupported=false
    /// - `"cm Scheibe Ingwer"` → measure="", remaining="Ingwer", hadUnsupported=true
    /// - `"EL Sojasauce"` → measure="", remaining="Sojasauce", hadUnsupported=true
    /// - `"Eier"` → measure="", remaining="Eier", hadUnsupported=false
    private static func consumeUnitTokens(
        from text: String
    ) -> (measure: String, remaining: String, hadUnsupportedToken: Bool) {
        var current = text.trimmingCharacters(in: .whitespaces)
        var hadUnsupported = false

        while !current.isEmpty {
            let lower = current.lowercased()
            var matchedToken: String?
            var matchedCanonical: String?

            for (token, canonical) in sortedAllKnownUnits {
                guard lower.hasPrefix(token) else { continue }
                let afterIdx   = current.index(current.startIndex, offsetBy: token.count)
                let atBoundary = afterIdx >= current.endIndex || current[afterIdx].isWhitespace
                guard atBoundary else { continue }
                matchedToken     = token
                matchedCanonical = canonical
                break
            }

            guard let token = matchedToken else { break }

            let afterIdx = current.index(current.startIndex, offsetBy: token.count)
            current = String(current[afterIdx...]).trimmingCharacters(in: .whitespaces)

            if let canonical = matchedCanonical {
                return (canonical, current, false)   // Unterstützte Einheit → speichern & stop
            }
            // Nicht unterstütztes Token → verwerfen & weitersuchen
            hadUnsupported = true
        }
        return ("", current, hadUnsupported)
    }

    // MARK: - Stage 3c: Trailing-Suffix

    /// `"Milch 1x"` → units=1, remaining="Milch". Keine Einheit gespeichert.
    private static func parseSuffixQuantity(
        _ text: String
    ) -> (units: Int, remaining: String)? {
        let pattern = #"^(.+?)\s+(\d+)x\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match      = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange  = Range(match.range(at: 1), in: text),
              let unitsRange = Range(match.range(at: 2), in: text)
        else { return nil }
        return (max(1, Int(text[unitsRange]) ?? 1), String(text[nameRange]))
    }

    // MARK: - Stage 4: Name / Notiz trennen

    /// Trennt Artikelname von optionalem Zusatztext.
    ///
    /// Priorität:
    /// 1. Erstes Komma außerhalb von Klammern → links = Name, rechts = Notiz
    /// 2. Erstes ` (` → links = Name, rechts = Klammer-Block + Nachtext
    /// 3. Kein Trennzeichen → gesamter Text ist der Name
    private static func extractNameAndNote(_ text: String) -> (name: String, note: String?) {
        var depth = 0
        for (offset, char) in text.enumerated() {
            switch char {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case "," where depth == 0:
                let idx  = text.index(text.startIndex, offsetBy: offset)
                let name = String(text[..<idx]).trimmingCharacters(in: .whitespaces)
                let note = String(text[text.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return (name, note.isEmpty ? nil : note) }
            default: break
            }
        }
        if let parenRange = text.range(of: " (") {
            let name = String(text[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let note = String(text[parenRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return (name, note.isEmpty ? nil : note) }
        }
        return (text.trimmingCharacters(in: .whitespaces), nil)
    }

    // MARK: - Hilfsfunktionen

    /// Konvertiert eine Double-Menge in Int (Minimum 1).
    /// 0.5 → 1, 0.3 → 1, 1.08 → 1, 3.0 → 3, 250.0 → 250.
    private static func quantityToUnits(_ quantity: Double) -> Int {
        max(1, Int(quantity))
    }
}
