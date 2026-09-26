/*
 ReceiptDay.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Datumsumwandlung für das Kassenzettel-Archiv: DATE-Spalte („yyyy-MM-dd“) und Zeitstempel von Postgres.

 🔰 Notes for Beginners:
 - Postgres liefert Zeitstempel mit Mikrosekunden („2026-09-26T08:12:03.123456+00:00“).
   ISO8601DateFormatter versteht das nicht; der Bruchteil wird deshalb vorher entfernt.
 - Der Kalendertag wird nach Ortszeit bestimmt und beim Lesen auf 12 Uhr gelegt, damit er sich nicht verschiebt.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptDay {
    /// Kalendertag nach Ortszeit (Einkauf am 26.09. um 00:30 bleibt der 26.09.).
    static func string(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// „2026-09-26“ → 12 Uhr Ortszeit an diesem Tag (stabil gegen Zeitzonen- und Sommerzeitwechsel).
    static func date(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    static func timestamp(_ string: String) -> Date? {
        let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }
}
