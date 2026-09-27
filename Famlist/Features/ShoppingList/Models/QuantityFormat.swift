/*
 QuantityFormat.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regeln für die Artikelmenge als Kommazahl: runden, eingetippten Text lesen, anzeigen.

 🔰 Notes for Beginners:
 - Die Menge ist ein Double (z. B. 1,5 kg). Damit keine Rechenreste wie 0,30000000000000004 entstehen,
   wird immer auf 2 Nachkommastellen gerundet – der Server speichert ebenfalls höchstens 2 (Migration 025).
 - Anzeige immer im deutschen Format wie beim Preis (PriceDisplaySetting): „1,5“, „2“, „1500“ (ohne Tausenderpunkt).
 - Eingabe akzeptiert Komma und Punkt.

 📝 Last Change:
 - Neu: Mengen mit Nachkommastellen.
 ------------------------------------------------------------------------
 */

import Foundation

enum QuantityFormat {
    /// Gültige Mengen beim Eintippen: 0,01 … 9999.
    static let range: ClosedRange<Double> = 0.01...9999
    /// Höchstens so viele Nachkommastellen.
    static let maxFractionDigits = 2

    /// Auf 2 Nachkommastellen gerundet.
    static func normalized(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// „1,5“ / „1.5“ → 1.5. `nil` bei leerem oder ungültigem Text; mehr als 2 Nachkommastellen werden gerundet.
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
        return normalized(value)
    }

    /// 1.5 → „1,5“, 2 → „2“, 1500 → „1500“.
    static func format(_ value: Double) -> String {
        normalized(value).formatted(.number
            .precision(.fractionLength(0...maxFractionDigits))
            .grouping(.never)
            .locale(Locale(identifier: "de_DE")))
    }

    /// Eingabetext beim Tippen säubern: nur Ziffern und ein Komma, höchstens 4 Vor- und 2 Nachkommastellen.
    static func sanitizeInput(_ raw: String) -> String {
        var integer = "", fraction = "", hasSeparator = false
        for ch in raw {
            if ch.isNumber {
                if hasSeparator {
                    if fraction.count < maxFractionDigits { fraction.append(ch) }
                } else if integer.count < 4 {
                    integer.append(ch)
                }
            } else if (ch == "," || ch == ".") && !hasSeparator {
                hasSeparator = true
            }
        }
        return hasSeparator ? "\(integer.isEmpty ? "0" : integer),\(fraction)" : integer
    }
}
