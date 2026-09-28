/*
 InsightFormat.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Deutsche Texte für Einkaufsdaten und Auswertung: Euro, Mengen mit Einheit, Wochentag, Uhrzeit, Monat.

 🔰 Notes for Beginners:
 - Alles in Europe/Berlin und de_DE (ReceiptTimes.calendar), unabhängig von der Geräteeinstellung.
 - Mengen über QuantityFormat, Einheiten wie in der Liste (Measure.fromExternal(…).localizedName).
 - Reine Funktionen, nicht an den Main Actor gebunden → auch in Berechnungen und Tests nutzbar.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum InsightFormat {
    private static let german = Locale(identifier: "de_DE")
    private static let weekdays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    /// „11,51 €“.
    static func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR").locale(german))
    }

    /// „385 €“ (ganze Euro, für Säulen und Schnitt).
    static func wholeEuro(_ value: Decimal) -> String {
        "\(NSDecimalNumber(decimal: value).doubleValue.rounded().formatted(.number.grouping(.never).locale(german))) €"
    }

    /// Einheit wie in der Liste: „pack“ → „Packung“, „g“ → „g“. Leer → nil.
    static func unit(_ measure: String?) -> String? {
        guard let measure = measure?.trimmingCharacters(in: .whitespaces), !measure.isEmpty else { return nil }
        return Measure.fromExternal(measure).localizedName
    }

    /// „250 g“, „1,5 l“; ohne Einheit nur die Zahl.
    static func amount(_ value: Double, measure: String?) -> String {
        let number = QuantityFormat.format(value)
        return unit(measure).map { "\(number) \($0)" } ?? number
    }

    /// „Do, 24.09.“
    static func weekdayDay(_ date: Date, calendar: Calendar = ReceiptTimes.calendar) -> String {
        let c = calendar.dateComponents([.weekday, .day, .month], from: date)
        return String(format: "%@, %02d.%02d.", weekdays[((c.weekday ?? 1) - 1) % 7], c.day ?? 0, c.month ?? 0)
    }

    static func year(_ date: Date, calendar: Calendar = ReceiptTimes.calendar) -> String {
        String(calendar.component(.year, from: date))
    }

    /// „17:42“
    static func clock(_ date: Date, calendar: Calendar = ReceiptTimes.calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// „September“ / „September 2026“.
    static func month(_ date: Date, withYear: Bool = false, calendar: Calendar = ReceiptTimes.calendar) -> String {
        let name = calendar.standaloneMonthSymbols[calendar.component(.month, from: date) - 1]
        return withYear ? "\(name) \(calendar.component(.year, from: date))" : name
    }

    /// „Sep“ (Säulenbeschriftung).
    static func monthShort(_ date: Date, calendar: Calendar = ReceiptTimes.calendar) -> String {
        let name = calendar.standaloneMonthSymbols[calendar.component(.month, from: date) - 1]
        return String(name.prefix(3))
    }
}
