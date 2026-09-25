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
 - Mengenzeilen („2 Stk x 1,29“, „2 x 1,29“) sind keine Positionen. Sie setzen die Stückzahl der Position,
   deren Betrag passt (2 × 1,29 = 2,58): zuerst die Position davor, sonst die nächste.
 - Übersprungen werden: Gewichtszeilen ohne Endpreis („0,534 kg x 2,99 EUR/kg“),
   Zahlungs- und Steuerzeilen (BAR, EC, KARTE, MwSt …), Pfand/Leergut.
 - Gewichtszeile MIT Endpreis („0,512 kg x 9,99 EUR/kg  5,11 A“): Der Endpreis gehört zum Artikelnamen
   in der Zeile davor (Zeile ohne Preis) bzw. ersetzt den Preis der vorherigen Position.
 - Rabattzeilen mit negativem Preis („-0,50“, „0,50-“, „Rabatt -0,50“) werden von der vorherigen
   Position abgezogen, aber nie unter 0.
 - Nach „SUMME“ / „ZU ZAHLEN“ (nur als ganzes Wort) folgt nur noch Zahlungsinfo → dort endet die Positionsliste.
 - Reine Funktion → Unit-Tests mit Beispiel-Bons (ReceiptParserTests).

 📝 Last Change:
 - 25.09.2026: Mengenzeilen setzen die Stückzahl der passenden Position; „2 x 1,29“ ist keine Position mehr.
 - 25.09.2026: Audit-Fixes – Rabatte mit nachgestelltem/alleinstehendem Minus, Rabatt nie unter 0,
   Summenwörter nur als ganzes Wort („SUMMERROLLS“ ist keine Summe), Gewichtszeilen mit Endpreis.
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptParser {
    /// Bekannte Ketten (Groß/Klein egal), in dieser Schreibweise angezeigt.
    static let knownStores = ["REWE", "EDEKA", "Lidl", "ALDI", "Netto", "Penny", "Kaufland", "dm", "Rossmann",
                              "Norma", "Globus", "tegut", "Marktkauf", "Bio Company", "denn's", "Müller", "real"]

    /// Nur als ganzes Wort erkannt → Zusammensetzungen, die bisher über das Präfix trafen, stehen explizit hier.
    private static let totalWords = ["SUMME", "GESAMT", "GESAMTSUMME", "GESAMTBETRAG", "ZU ZAHLEN", "ZUZAHLEN",
                                     "TOTAL", "ENDSUMME"]
    private static let skipWords = ["MWST", "MWST.", "STEUER", "NETTO", "BRUTTO", "BAR", "GEGEBEN", "RÜCKGELD", "RUECKGELD",
                                    "EC-KARTE", "EC KARTE", "KARTENZAHLUNG", "GIROCARD", "VISA", "MASTERCARD", "KREDITKARTE",
                                    "PFAND", "LEERGUT", "PAYBACK", "BONUS", "TSE", "SIGNATUR", "TRANSAKTION", "KASSE", "BELEG"]

    /// Preis am Zeilenende, optional gefolgt von Steuerkennzeichen: „2,49 A“, „-0,50“, „0,50-“, „1.39 B*“, „3,49 €“.
    /// Der Preis darf auch allein in der Zeile stehen („-0,50“). Gruppe 3 = nachgestelltes Minus.
    private static let pricePattern =
        #"^(.*?)(?:^|[\s€]+)(-?\d{1,4}[.,]\d{2})(-?)\s*(?:€|EUR)?\s*(?:[A-Z]|\d|\*|[A-Z]\s?\*)?\s*$"#
    private static let quantityPattern = #"^\s*\d+([.,]\d+)?\s*(stk|st|x|kg|g)\b.*\b(x|à|a)\b.*\d+[.,]\d{2}"#
    /// Reine Mengenzeile: „2 Stk x 1,29“, „3 St. x 0,99“, „2 x 1,29“. Gruppe 1 = Stückzahl, Gruppe 2 = Stückpreis.
    private static let countPattern = #"^(\d{1,3})\s*(?:STK|ST)?\.?\s*[X×*]\s*(\d{1,4}[.,]\d{2})\s*(?:€|EUR)?\s*$"#
    private static let datePattern = #"(\d{1,2})\.(\d{1,2})\.(\d{2,4})"#

    static func parse(lines rawLines: [String]) -> ParsedReceipt {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var result = ParsedReceipt(store: detectStore(lines), date: detectDate(lines), lines: [], total: nil)
        var pendingName: String?        // Artikelname ohne Preis direkt in der Zeile davor
        var pendingCount: (count: Int, amount: Decimal)?   // Mengenzeile, die vor ihrer Position steht

        for line in lines {
            let upper = line.uppercased()
            if isTotalLine(upper) {
                if result.total == nil, let price = trailingPrice(line) { result.total = price }
                if result.total != nil { break }               // danach nur Zahlung/Steuer
                continue
            }
            let nameBefore = pendingName
            pendingName = nil
            if isWeightLine(upper) {
                applyWeightLine(line, nameBefore: nameBefore, to: &result)
                continue
            }
            if let count = countLine(line) {
                if !applyCount(count, toLastOf: &result) { pendingCount = count }
                continue
            }
            if isSkippable(upper) || line.range(of: quantityPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                continue
            }
            guard let (text, price) = split(line) else { pendingName = articleName(line); continue }
            if price < 0 { applyDiscount(price, to: &result); continue }
            guard let name = articleName(text) else { continue }
            var entry = ParsedReceipt.Line(raw: name, price: price)
            if let count = pendingCount, count.count > 1, count.amount == price { entry.quantity = count.count }
            pendingCount = nil
            result.lines.append(entry)
        }
        return result
    }

    // MARK: - Positionen

    /// Rabatt: von der vorherigen Position abziehen, nie unter 0.
    private static func applyDiscount(_ discount: Decimal, to result: inout ParsedReceipt) {
        guard let last = result.lines.popLast() else { return }
        result.lines.append(.init(raw: last.raw, price: max(0, last.price + discount), quantity: last.quantity))
    }

    /// Mengenzeile → (Stückzahl, Betrag = Stückzahl × Stückpreis).
    private static func countLine(_ line: String) -> (count: Int, amount: Decimal)? {
        guard let regex = try? NSRegularExpression(pattern: countPattern, options: .caseInsensitive),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let countRange = Range(m.range(at: 1), in: line), let count = Int(line[countRange]),
              let unitRange = Range(m.range(at: 2), in: line),
              let unit = Decimal(string: line[unitRange].replacingOccurrences(of: ",", with: "."),
                                 locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return (count, unit * Decimal(count))
    }

    /// Stückzahl an die vorherige Position hängen, wenn deren Betrag passt. false → gehört zur nächsten.
    private static func applyCount(_ count: (count: Int, amount: Decimal), toLastOf result: inout ParsedReceipt) -> Bool {
        guard count.count > 1, let last = result.lines.last, last.quantity == 1, last.price == count.amount else { return false }
        result.lines[result.lines.count - 1].quantity = count.count
        return true
    }

    /// Gewichtszeile („0,512 kg x 9,99 EUR/kg  5,11 A“). Ohne Endpreis → ignorieren.
    /// Mit Endpreis → neue Position mit dem Namen aus der Zeile davor, sonst Preis der vorherigen Position ersetzen.
    private static func applyWeightLine(_ line: String, nameBefore: String?, to result: inout ParsedReceipt) {
        guard let (text, price) = split(line), price >= 0, isWeightLine(text.uppercased()) else { return }
        if let name = nameBefore {
            result.lines.append(.init(raw: name, price: price))
        } else if let last = result.lines.popLast() {
            result.lines.append(.init(raw: last.raw, price: price))
        }
    }

    /// Bereinigter Artikelname, wenn er Buchstaben enthält und mind. 2 Zeichen lang ist.
    private static func articleName(_ text: String) -> String? {
        let name = clean(text)
        guard name.rangeOfCharacter(from: .letters) != nil, name.count >= 2 else { return nil }
        return name
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
        let trailingMinus = Range(m.range(at: 3), in: line).map { !line[$0].isEmpty } ?? false
        return (String(line[textRange]), trailingMinus ? -abs(price) : price)
    }

    /// Nur ganze Wörter zählen („BAR“ überspringt „Geg. BAR“, aber nicht „BARILLA“).
    private static func isSkippable(_ upper: String) -> Bool {
        skipWords.contains { containsWord($0, in: upper) }
    }

    /// Summenzeile: „SUMME“, „ZU ZAHLEN“ … nur als ganzes Wort („SUMMERROLLS“, „TOTALSCHADEN“ zählen nicht).
    private static func isTotalLine(_ upper: String) -> Bool {
        totalWords.contains { containsWord($0, in: upper) }
    }

    /// Gewichtszeile mit Kilopreis („… EUR/kg“, „… €/kg“).
    private static func isWeightLine(_ upper: String) -> Bool {
        upper.contains("EUR/KG") || upper.contains("€/KG")
    }

    /// true, wenn `word` in `upper` als ganzes Wort vorkommt (keine Buchstaben direkt davor/danach).
    private static func containsWord(_ word: String, in upper: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        return upper.range(of: "(^|[^A-ZÄÖÜ])\(escaped)([^A-ZÄÖÜ]|$)", options: .regularExpression) != nil
    }

    /// Mehrfache Leerzeichen und Stern-/Punkt-Füllzeichen entfernen.
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"[.*]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
