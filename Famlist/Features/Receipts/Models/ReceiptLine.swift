/*
 ReceiptLine.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Position eines gespeicherten Kassenzettels: Bon-Text, zugeordneter Artikel, Betrag, Stückzahl.
   Liegt im Archiv-Eintrag (Spalte receipts.lines, Migration 029).

 🔰 Notes for Beginners:
 - Entsteht beim „Preise speichern“ aus den Zeilen von „Kassenzettel prüfen“ (ReceiptReviewLine).
 - Ignorierte Zeilen werden nicht gespeichert (seit 29.09.2026; ältere Bons enthalten sie noch).
 - `itemName` ist nil, wenn die Zeile keinem Artikel zugeordnet ist.
 - `isSaved`: Für diese Zeile wurde ein Preis in den Preisverlauf geschrieben.
 - Die Schlüssel im JSON sind kurz und klein geschrieben, wie in der Datenbank üblich (unit_price statt unitPrice).
 - `category`, `units`, `measure`, `itemId` (Migration 030) fehlen bei älteren Bons; die Anzeige schlägt sie dann nach.
   `units` ist der Inhalt je Stück: Listenmenge ÷ Stückzahl auf dem Bon (Entscheidung Robert 29.09.2026),
   „Schokolade 200 g“ und „2 ×“ auf dem Bon ergeben also 100 g je Stück.

 📝 Last Change:
 - Kategorie, Inhalt je Stück, Einheit und Artikel-ID je Zeile (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptLine: Codable, Equatable, Sendable {
    let raw: String
    let itemName: String?
    /// Zeilenbetrag laut Bon (bei „2 Stk x 1,29“ also 2,58).
    let price: Decimal
    let unitPrice: Decimal
    let quantity: Int
    let isSaved: Bool
    /// Kategorie-Name beim Speichern (nil = alter Bon oder nicht zugeordnet).
    var category: String? = nil
    /// Inhalt je Stück in `measure` (nil = unbekannt).
    var units: Double? = nil
    /// Einheit wie im Artikel („g“, „l“, „Stück“ …).
    var measure: String? = nil
    /// ID des zugeordneten Listen- oder Stammartikels.
    var itemId: String? = nil

    enum CodingKeys: String, CodingKey {
        case raw
        case itemName = "item"
        case price
        case unitPrice = "unit_price"
        case quantity
        case isSaved = "saved"
        case category
        case units
        case measure
        case itemId = "item_id"
    }

    init(raw: String, itemName: String?, price: Decimal, unitPrice: Decimal, quantity: Int, isSaved: Bool) {
        self.raw = raw
        self.itemName = itemName
        self.price = price
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.isSaved = isSaved
    }

    /// Aus „Kassenzettel prüfen“: Nicht bestätigte neue Zeilen behalten keinen Artikel.
    init(_ line: ReceiptReviewLine) {
        self.init(raw: line.raw, itemName: line.isSaved ? line.itemName : nil, price: line.price,
                  unitPrice: line.unitPrice, quantity: line.quantity, isSaved: line.isSaved)
    }
}
