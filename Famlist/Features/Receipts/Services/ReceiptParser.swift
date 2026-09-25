/*
 ReceiptParser.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Liest aus den OCR-Zeilen eines deutschen Kassenbons Laden, Datum, Positionen und Summe.

 🔰 Notes for Beginners:
 - Eingabe sind Textzeilen (von oben nach unten), wie sie ReceiptTextRecognizer aus Vision liefert.
 - Position = Text + Preis am Zeilenende („KERRYGOLD BUTTER   2,49 A“). Der Steuer-Buchstabe (A/B/1/2, *)
   nach dem Preis wird ignoriert.
 - Übersprungen werden: Mengenzeilen („2 Stk x 1,29“), Gewichtszeilen („0,534 kg x 2,99 EUR/kg“),
   Zahlungs- und Steuerzeilen (BAR, EC, KARTE, MwSt …), Pfand/Leergut.
 - Rabattzeilen mit negativem Preis werden von der vorherigen Position abgezogen.
 - Nach „SUMME“ / „ZU ZAHLEN“ folgt nur noch Zahlungsinfo → dort endet die Positionsliste.
 - Reine Funktion → Unit-Tests mit Beispiel-Bons (ReceiptParserTests).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptParser {
    /// Bekannte Ketten (Groß/Klein egal), in dieser Schreibweise angezeigt.
    static let knownStores = ["REWE", "EDEKA", "Lidl", "ALDI", "Netto", "Penny", "Kaufland", "dm", "Rossmann",
                              "Norma", "Globus", "tegut", "Marktkauf", "Bio Company", "denn's", "Müller", "real"]

    private static let totalWords = ["SUMME", "GESAMT", "ZU ZAHLEN", "ZUZAHLEN", "TOTAL", "ENDSUMME"]
    private static let skipWords = ["MWST", "MWST.", "STEUER", "NETTO", "BRUTTO", "BAR", "GEGEBEN", "RÜCKGELD", "RUECKGELD",
                                    "EC-KARTE", "EC KARTE", "KARTENZAHLUNG", "GIROCARD", "VISA", "MASTERCARD", "KREDITKARTE",
                                    "PFAND", "LEERGUT", "PAYBACK", "BONUS", "TSE", "SIGNATUR", "TRANSAKTION", "KASSE", "BELEG"]

    /// Preis am Zeilenende, optional gefolgt von Steuerkennzeichen: „2,49 A“, „-0,50“, „1.39 B*“, „3,49 €“.
    private static let pricePattern = #"^(.*?)[\s€]+(-?\d{1,4}[.,]\d{2})\s*(?:€|EUR)?\s*(?:[A-Z]|\d|\*|[A-Z]\s?\*)?\s*$"#
    private static let quantityPattern = #"^\s*\d+([.,]\d+)?\s*(stk|st|x|kg|g)\b.*\b(x|à|a)\b.*\d+[.,]\d{2}"#
    private static let datePattern = #"(\d{1,2})\.(\d{1,2})\.(\d{2,4})"#

    static func parse(lines rawLines: [String]) -> ParsedReceipt {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var result = ParsedReceipt(store: detectStore(lines), date: detectDate(lines), lines: [], total: nil)

        for line in lines {
            let upper = line.uppercased()
            if totalWords.contains(where: { upper.hasPrefix($0) || upper.contains(" \($0)") }) {
                if result.total == nil, let price = trailingPrice(line) { result.total = price }
                if result.total != nil { break }               // danach nur Zahlung/Steuer
                continue
            }
            if isSkippable(upper) || line.range(of: quantityPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                continue
            }
            guard let (text, price) = split(line) else { continue }
            if price < 0 {
                // Rabatt: von der vorherigen Position abziehen
                if let last = result.lines.popLast() {
                    result.lines.append(.init(raw: last.raw, price: last.price + price))
                }
                continue
            }
            let name = clean(text)
            guard name.rangeOfCharacter(from: .letters) != nil, name.count >= 2 else { continue }
            result.lines.append(.init(raw: name, price: price))
        }
        return result
    }

    // MARK: - Teile

    static func detectStore(_ lines: [String]) -> String? {
        let head = lines.prefix(8)
        for line in head {
            let lower = line.lowercased()
            if let store = knownStores.first(where: { lower.range(of: "\\b\($0.lowercased())\\b", options: .regularExpression) != nil }) {
                return store
            }
        }
        return nil
    }

    static func detectDate(_ lines: [String]) -> Date? {
        for line in lines {
            guard let match = line.range(of: datePattern, options: .regularExpression) else { continue }
            let parts = line[match].split(separator: ".").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            var year = parts[2]
            if year < 100 { year += 2000 }
            var c = DateComponents()
            c.day = parts[0]; c.month = parts[1]; c.year = year
            guard (1...31).contains(parts[0]), (1...12).contains(parts[1]), (2000...2100).contains(year),
                  let date = Calendar(identifier: .gregorian).date(from: c) else { continue }
            return date
        }
        return nil
    }

    static func trailingPrice(_ line: String) -> Decimal? { split(line)?.1 }

    /// Zerlegt eine Zeile in Text und Preis am Ende.
    static func split(_ line: String) -> (String, Decimal)? {
        guard let regex = try? NSRegularExpression(pattern: pricePattern),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let textRange = Range(m.range(at: 1), in: line),
              let priceRange = Range(m.range(at: 2), in: line) else { return nil }
        let priceText = line[priceRange].replacingOccurrences(of: ",", with: ".")
        guard let price = Decimal(string: priceText, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return (String(line[textRange]), price)
    }

    /// Nur ganze Wörter zählen („BAR“ überspringt „Geg. BAR“, aber nicht „BARILLA“).
    private static func isSkippable(_ upper: String) -> Bool {
        if upper.contains("EUR/KG") || upper.contains("€/KG") { return true }
        return skipWords.contains { word in
            let escaped = NSRegularExpression.escapedPattern(for: word)
            return upper.range(of: "(^|[^A-ZÄÖÜ])\(escaped)([^A-ZÄÖÜ]|$)", options: .regularExpression) != nil
        }
    }

    /// Mehrfache Leerzeichen und Stern-/Punkt-Füllzeichen entfernen.
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"[.*]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
