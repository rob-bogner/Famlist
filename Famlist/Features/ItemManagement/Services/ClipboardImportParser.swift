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

    /// Dezimalmengen dieser Einheiten werden in die kleinere Einheit umgerechnet.
    /// Ziel-Tokens sind die rawValues der `Measure`-Enum (dieselben, die `MeasureCanonicalizer` liefert).
    private static let smallerUnits: [String: (measure: String, factor: Double)] = [
        Measure.kg.rawValue: (Measure.g.rawValue, 1000),
        Measure.l.rawValue:  (Measure.ml.rawValue, 1000),
        Measure.m.rawValue:  (Measure.cm.rawValue, 100),
    ]

    /// Aufzählungszeichen und Checkboxen am Zeilenanfang: „- “, „• “, „* “, „☐ “, „☑ “, „✓ “,
    /// „1. “, „1) “, „[ ] “, „[x] “ – auch kombiniert („- [ ] Mehl“).
    private static let bulletPattern =
        #"^(?:[•·☐☑☒✓✔]\s*|(?:[-–*]|\[[ xX]?\]|\d{1,3}[.)])\s+)+"#

    /// Multiplikator vor dem Namen: `2x`, `2 x`, `2×`, `x2`, `× 2`.
    private static let multiplierPattern = #"(?:(\d+(?:[,.]\d+)?)\s*[x×]|[x×]\s*(\d+))"#

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

    // MARK: - Ladenname (erste Zeile)

    /// Liefert die erste nicht-leere Zeile als Ladennamen, wenn sie eindeutig kein Artikel ist:
    /// - endet auf „:“ (`Edeka:` → „Edeka“)
    /// - ist eine bekannte Kette aus `ReceiptParser.knownStores` (`Rewe`)
    /// - steht allein vor einer Leerzeile, auf die eine Kategorie folgt (`Edeka\n\n[Obst]` – Export-Format)
    /// `[Obst]` bleibt wie bisher eine Kategorie. Sonst → nil, die Zeile wird als Artikel importiert.
    private static func detectStoreName(in rawLines: [String]) -> String? {
        guard let firstIdx = rawLines.firstIndex(where: { !$0.isEmpty }) else { return nil }
        let first = rawLines[firstIdx]
        if first.hasPrefix("[") { return nil }
        if first.hasSuffix(":") {
            let name = String(first.dropLast()).trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        let isKnownStore = ReceiptParser.knownStores.contains { $0.caseInsensitiveCompare(first) == .orderedSame }
        if isKnownStore || isHeaderBeforeCategory(rawLines, after: firstIdx) { return first }
        return nil
    }

    /// true, wenn direkt nach `index` eine Leerzeile folgt und die nächste Textzeile eine Kategorie ist.
    private static func isHeaderBeforeCategory(_ rawLines: [String], after index: Int) -> Bool {
        let rest = rawLines[(index + 1)...]
        guard rest.first?.isEmpty == true,
              let next = rest.first(where: { !$0.isEmpty }) else { return false }
        return parseCategoryLine(next) != nil
    }

    // MARK: - Stage 1: Normalisierung

    /// Entfernt auch Aufzählungszeichen/Checkboxen am Anfang. Abgehakte Zeilen („☑“, „[x]“)
    /// werden wie offene Artikel importiert – `ParsedItem` kennt keinen Erledigt-Status.
    private static func normalizeLine(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: bulletPattern, with: "", options: .regularExpression)
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

        let parsed = parseQuantity(line)

        // Stage 4: Name / Notiz trennen
        let (name, note) = extractNameAndNote(parsed.remaining)
        guard !name.isEmpty else { return nil }

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
        return QuantityParse(remaining: text)
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

    // MARK: - Stage 3b: Führender Multiplikator

    /// `2x Milch`, `2 x Milch`, `2× Milch`, `x2 Milch` → qty=2, remaining="Milch".
    /// Nach dem `x` muss ein Leerzeichen folgen, damit `2 XL-Shirts` nicht getroffen wird.
    private static func parseLeadingMultiplier(
        _ text: String
    ) -> (quantity: Double, remaining: String)? {
        let pattern = "^" + multiplierPattern + #"\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match     = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let number    = firstGroup(of: match, in: text, groups: [1, 2]),
              let restRange = Range(match.range(at: 3), in: text)
        else { return nil }
        return (parseQuantityString(number), String(text[restRange]))
    }

    /// Text der ersten Regex-Gruppe aus `groups`, die getroffen hat.
    private static func firstGroup(of match: NSTextCheckingResult, in text: String, groups: [Int]) -> String? {
        for group in groups {
            if let range = Range(match.range(at: group), in: text) { return String(text[range]) }
        }
        return nil
    }

    // MARK: - Stage 3c: Numerische führende Menge

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

    // MARK: - Stage 3c: Einheiten-Konsum

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

    // MARK: - Stage 3d: Trailing-Suffix

    /// `"Milch 1x"`, `"Milch x2"`, `"Milch 2×"` → units, remaining="Milch". Keine Einheit gespeichert.
    private static func parseSuffixQuantity(
        _ text: String
    ) -> (units: Int, remaining: String)? {
        let pattern = #"^(.+?)\s+"# + multiplierPattern + #"\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match     = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text),
              let number    = firstGroup(of: match, in: text, groups: [2, 3])
        else { return nil }
        return (max(1, Int(parseQuantityString(number).rounded(.up))), String(text[nameRange]))
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

    /// Wandelt eine explizite Menge in ganze Einheiten um (Minimum 1).
    /// - Ohne Einheit → "piece".
    /// - Dezimalmenge bei kg/l/m → kleinere Einheit: 1,5 kg → 1500 g, 0,5 l → 500 ml, 1,5 m → 150 cm.
    /// - Sonst aufrunden auf ganze Stück: 1,5 Brot → 2, 0,5 → 1, 3,0 → 3.
    private static func resolveUnits(_ quantity: Double, measure: String) -> (units: Int, measure: String) {
        let measure = measure.isEmpty ? "piece" : measure
        let isWhole = abs(quantity - quantity.rounded()) < 0.0001
        if !isWhole, let smaller = smallerUnits[measure] {
            return (max(1, Int((quantity * smaller.factor).rounded())), smaller.measure)
        }
        // Kleine Toleranz, damit Rundungsfehler (2.0000001) nicht auf 3 aufrunden.
        return (max(1, Int((quantity - 0.0001).rounded(.up))), measure)
    }
}
