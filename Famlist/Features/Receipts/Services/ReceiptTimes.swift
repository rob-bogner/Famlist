/*
 ReceiptTimes.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Beginn und Ende eines Einkaufs für den Archiv-Eintrag (receipts.started_at / ended_at, Migration 030).

 🔰 Notes for Beginners:
 - Ende = Einkaufstag laut Bon + Uhrzeit laut Bon (Europe/Berlin).
 - Ohne Uhrzeit auf dem Bon: Zeitpunkt der ersten Aufnahme, aber nur, wenn sie am Einkaufstag war.
   Wer einen alten Bon heute fotografiert, bekäme sonst eine falsche Uhrzeit.
 - Beginn = erstes Abhaken in der Liste (ShoppingStartStore), nur wenn plausibel zum Ende.
 - Reine Funktion → Unit-Tests (ReceiptTimesTests).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptTimes {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ReceiptParser.berlin
        calendar.locale = Locale(identifier: "de_DE")
        return calendar
    }

    /// (Beginn, Ende). `day` = Einkaufstag laut Bon (sonst Tag der Aufnahme), `time` = Uhrzeit laut Bon.
    static func make(day: Date, time: DateComponents?, capturedAt: Date?, listStart: Date?,
                     calendar: Calendar = calendar) -> (start: Date?, end: Date?) {
        let end = ended(day: day, time: time, capturedAt: capturedAt, calendar: calendar)
        return (ShoppingStartStore.plausibleStart(listStart, end: end), end)
    }

    private static func ended(day: Date, time: DateComponents?, capturedAt: Date?, calendar: Calendar) -> Date? {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        if let hour = time?.hour, let minute = time?.minute {
            var parts = dayParts
            parts.hour = hour
            parts.minute = minute
            return calendar.date(from: parts)
        }
        guard let capturedAt, calendar.isDate(capturedAt, inSameDayAs: day) else { return nil }
        return capturedAt
    }
}
