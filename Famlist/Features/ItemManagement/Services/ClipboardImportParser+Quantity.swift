/*
 ClipboardImportParser+Quantity.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengen-Stufen des Clipboard-Imports: Klammer-Menge, Multiplikator, führende Zahl, Suffix und nachgestellte Menge.

 📝 Last Change:
 - Aus ClipboardImportParser.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ClipboardImportParser {
    /// Multiplikator vor dem Namen: `2x`, `2 x`, `2×`, `x2`, `× 2`.
    private static let multiplierPattern = #"(?:(\d+(?:[,.]\d+)?)\s*[x×]|[x×]\s*(\d+))"#

    // MARK: - Stage 3a: Führende Klammer-Menge

    /// `(2) Eier` → qty=2, remaining="Eier"
    /// `(2) 2-3 Frühlingszwiebeln` → qty=2, remaining="2-3 Frühlingszwiebeln"
    ///
    /// Nur reine Ganzzahlen in den Klammern werden akzeptiert;
    /// `(Jasmin 1:1,3)` wird NICHT gematcht.
    static func parseLeadingParenQuantity(
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
    static func parseLeadingMultiplier(
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
    static func parseLeadingQuantityToken(
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

    // MARK: - Stage 3d: Trailing-Suffix

    /// `"Milch 1x"`, `"Milch x2"`, `"Milch 2×"` → units, remaining="Milch". Keine Einheit gespeichert.
    static func parseSuffixQuantity(
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

    // MARK: - Stage 3e: Nachgestellte Menge mit Einheit

    /// `Milch 2 l` → qty=2, measure="l", remaining="Milch".
    /// Nur mit einer unterstützten Einheit: `Vitamin C 500` oder `Milch 3,5 %` bleiben unverändert.
    static func parseTrailingUnitQuantity(
        _ text: String
    ) -> (quantity: Double, measure: String, remaining: String)? {
        let pattern = #"^(.+?)\s+(\d+(?:[.,]\d+)?)\s*([\p{L}]+\.?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match     = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text),
              let numRange  = Range(match.range(at: 2), in: text),
              let unitRange = Range(match.range(at: 3), in: text),
              let measure   = supportedUnitsMap[text[unitRange].lowercased()]
        else { return nil }
        return (parseQuantityString(String(text[numRange])), measure, String(text[nameRange]))
    }
}
