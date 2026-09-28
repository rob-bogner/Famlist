/*
 ReceiptMetaTile.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Kachel der Einkaufsdaten im Bon-Detail (Ort, Datum, Uhrzeit, Dauer, Artikel, Wert).

 🔰 Notes for Beginners:
 - Unbekannte Werte stehen als „–“ ohne Unterzeile (RECEIPT_INSIGHTS_PROMPT.md, Design §2).
 - `kind` bestimmt das Icon (ReceiptMetaIcon) und die Beschriftung.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptMetaTile: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case store = "Ort"
        case date = "Datum"
        case time = "Uhrzeit"
        case duration = "Dauer"
        case items = "Artikel"
        case value = "Wert"
    }

    let kind: Kind
    let value: String
    let sub: String?

    var id: String { kind.rawValue }
    var label: String { kind.rawValue }

    static let unknown = "–"

    static func unknown(_ kind: Kind) -> ReceiptMetaTile {
        ReceiptMetaTile(kind: kind, value: unknown, sub: nil)
    }
}
