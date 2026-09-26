/*
 ClipboardImportParser+Lines.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeilen-Stufen des Clipboard-Imports: Ladenname, Normalisierung, Kategorie-Zeilen und Trennung von Name und Notiz.

 📝 Last Change:
 - Aus ClipboardImportParser.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ClipboardImportParser {
    /// Aufzählungszeichen und Checkboxen am Zeilenanfang: „- “, „• “, „* “, „☐ “, „☑ “, „✓ “,
    /// „1. “, „1) “, „[ ] “, „[x] “ – auch kombiniert („- [ ] Mehl“).
    private static let bulletPattern =
        #"^(?:[•·☐☑☒✓✔]\s*|(?:[-–*]|\[[ xX]?\]|\d{1,3}[.)])\s+)+"#

    // MARK: - Ladenname (erste Zeile)

    /// Liefert die erste nicht-leere Zeile als Ladennamen, wenn sie eindeutig kein Artikel ist:
    /// - endet auf „:“ (`Edeka:` → „Edeka“)
    /// - ist eine bekannte Kette aus `ReceiptParser.knownStores` (`Rewe`)
    /// - steht allein vor einer Leerzeile, auf die eine Kategorie folgt (`Edeka\n\n[Obst]` – Export-Format)
    /// `[Obst]` bleibt wie bisher eine Kategorie. Sonst → nil, die Zeile wird als Artikel importiert.
    static func detectStoreName(in rawLines: [String]) -> String? {
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
    static func normalizeLine(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: bulletPattern, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#,  with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+,"#,    with: ",", options: .regularExpression)
        return s
    }

    // MARK: - Stage 2: Kategorie-Erkennung

    static func parseCategoryLine(_ line: String) -> String? {
        guard line.hasPrefix("["), line.hasSuffix("]") else { return nil }
        return String(line.dropFirst().dropLast())
    }

    // MARK: - Stage 4: Name / Notiz trennen

    /// Trennt Artikelname von optionalem Zusatztext.
    ///
    /// Priorität:
    /// 1. Erstes Komma außerhalb von Klammern → links = Name, rechts = Notiz
    /// 2. Erstes ` (` → links = Name, rechts = Klammer-Block + Nachtext
    /// 3. Kein Trennzeichen → gesamter Text ist der Name
    static func extractNameAndNote(_ text: String) -> (name: String, note: String?) {
        var depth = 0
        let chars = Array(text)
        for (offset, char) in chars.enumerated() {
            // Dezimalkomma („Milch 3,5 %“) ist kein Trenner zwischen Name und Notiz.
            let isDecimalComma = offset > 0 && offset + 1 < chars.count
                && chars[offset - 1].isNumber && chars[offset + 1].isNumber
            switch char {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case "," where depth == 0 && !isDecimalComma:
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
}
