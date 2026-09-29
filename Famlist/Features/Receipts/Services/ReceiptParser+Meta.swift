/*
 ReceiptParser+Meta.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einkaufsdaten aus dem Bon-Text: Uhrzeit des Einkaufs und Adresse des Ladens.

 🔰 Notes for Beginners:
 - Uhrzeit: zuerst in der Datumszeile („24.09.2026 17:42“), dann in den Zeilen direkt darunter oder
   darüber („Uhrzeit: 17:42:10 Uhr“), zuletzt im TSE-Zeitstempel („TSE-Stop: 2026-09-24T17:42:10“).
   Preise stehen mit Komma, Uhrzeiten mit Doppelpunkt – daher keine Verwechslung.
 - TSE-Zeitstempel mit „Z“ oder „+00:00“ sind UTC und werden nach Europe/Berlin umgerechnet.
 - Adresse: erste Zeile mit Straße und Hausnummer („Leopoldstr. 82“) in den Zeilen nach dem Laden,
   sonst eine Zeile „PLZ Ort“ („80802 München“). Findet sich nichts, bleibt das Feld leer.
   Von der Straßenzeile zählt nur „Straße Hausnummer“: Legt Vision andere Wörter in dieselbe Zeile
   („Josephsburgstr. 37   REWE“), fallen sie weg.
 - Reine Funktionen → Unit-Tests (ReceiptParserMetaTests).

 📝 Last Change:
 - 29.09.2026: Adresse ohne fremde Wörter aus derselben OCR-Zeile.
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

extension ReceiptParser {
    /// Uhrzeit „17:42“ oder „17:42:10“; nicht Teil einer längeren Zahl und nicht Teil eines
    /// TSE-Zeitstempels („…T15:12:40Z“ ist UTC und wird gesondert umgerechnet).
    private static let timePattern = #"(?<![\d:T])([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?(?![\d:])"#
    /// TSE-Zeitstempel „2026-09-24T17:42:10(.000)(Z|+00:00)“. Gruppe 1/2 = Stunde/Minute, Gruppe 3 = Zone.
    private static let isoPattern = #"\d{4}-\d{2}-\d{2}T(\d{2}):(\d{2})(?::\d{2})?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?"#
    /// Straße mit Hausnummer: „Leopoldstr. 82“, „Hauptstraße 12a“, „Am Mühlweg 3“.
    private static let streetPattern =
        #"^[A-ZÄÖÜa-zäöüß][A-ZÄÖÜa-zäöüß.\- ]*?(str\.?|straße|strasse|weg|platz|allee|gasse|ring|damm|ufer|chaussee)\s*\d{1,4}\s*[a-zA-Z]?\b"#
    /// „80802 München“.
    private static let postalPattern = #"^\d{5}\s+[A-ZÄÖÜa-zäöü]"#

    static let berlin = TimeZone(identifier: "Europe/Berlin") ?? .current

    // MARK: - Uhrzeit

    static func detectTime(_ lines: [String]) -> DateComponents? {
        if let index = lines.firstIndex(where: { detectDate([$0]) != nil }) {
            for offset in [0, 1, -1, 2, -2] where lines.indices.contains(index + offset) {
                if let time = clockTime(in: lines[index + offset]) { return time }
            }
        }
        return tseTime(lines)
    }

    /// Erste Uhrzeit in einer Zeile.
    private static func clockTime(in line: String) -> DateComponents? {
        guard let m = firstMatch(timePattern, in: line),
              let hour = Int(m[1]), let minute = Int(m[2]) else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }

    /// TSE-Zeitstempel: „Stop“/„Ende“ bevorzugt, sonst der letzte gefundene.
    private static func tseTime(_ lines: [String]) -> DateComponents? {
        let candidates = lines.filter { firstMatch(isoPattern, in: $0) != nil }
        let upper = { (line: String) in line.uppercased() }
        guard let line = candidates.first(where: { upper($0).contains("STOP") || upper($0).contains("ENDE") })
                ?? candidates.last,
              let m = firstMatch(isoPattern, in: line),
              var hour = Int(m[1]), let minute = Int(m[2]) else { return nil }
        if isUTC(m[3]) {
            // UTC → Berlin: Versatz am Einkaufstag (Sommer-/Winterzeit) aus dem Zeitstempel selbst.
            let offset = berlin.secondsFromGMT(for: isoDate(line) ?? Date()) / 3600
            hour = (hour + offset + 24) % 24
        }
        return DateComponents(hour: hour, minute: minute)
    }

    private static func isUTC(_ zone: String) -> Bool {
        zone == "Z" || zone == "+00:00" || zone == "+0000" || zone == "-00:00"
    }

    private static func isoDate(_ line: String) -> Date? {
        guard let range = line.range(of: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}"#, options: .regularExpression) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: String(line[range]))
    }

    // MARK: - Adresse

    /// Straße der Filiale (sonst PLZ und Ort) in den Zeilen nach dem Laden.
    static func detectAddress(_ lines: [String]) -> String? {
        let head = Array(lines.prefix(12))
        let start = detectStore(Array(head.prefix(8))).flatMap { store in
            head.firstIndex { $0.lowercased().contains(store.lowercased()) }
        } ?? 0
        // Zeilen mit Preis („BIO RING 2,49“) sind Positionen, keine Adresse.
        let window = head.dropFirst(start).filter { $0.range(of: #"\d,\d{2}"#, options: .regularExpression) == nil }
        let street = window.lazy.compactMap { firstMatch(streetPattern, in: $0, options: .caseInsensitive)?[0] }.first
        let found = street ?? window.first { firstMatch(postalPattern, in: $0) != nil }
        return found.map { String(tidy($0).prefix(200)) }
    }

    /// Mehrfache Leerzeichen entfernen.
    private static func tidy(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Regex

    /// Alle Gruppen des ersten Treffers (Index 0 = ganzer Treffer, nicht gefundene Gruppen = "").
    private static func firstMatch(_ pattern: String, in line: String,
                                   options: NSRegularExpression.Options = []) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: line).map { String(line[$0]) } ?? ""
        }
    }
}
