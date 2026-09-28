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
 - `itemName` ist nil, wenn die Zeile ignoriert wurde oder keinem Artikel zugeordnet ist.
 - `isSaved`: Für diese Zeile wurde ein Preis in den Preisverlauf geschrieben.
 - Die Schlüssel im JSON sind kurz und klein geschrieben, wie in der Datenbank üblich (unit_price statt unitPrice).

 📝 Last Change:
 - Initial creation (Kassenzettel mit seinen Artikeln).
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

    enum CodingKeys: String, CodingKey {
        case raw
        case itemName = "item"
        case price
        case unitPrice = "unit_price"
        case quantity
        case isSaved = "saved"
    }

    init(raw: String, itemName: String?, price: Decimal, unitPrice: Decimal, quantity: Int, isSaved: Bool) {
        self.raw = raw
        self.itemName = itemName
        self.price = price
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.isSaved = isSaved
    }

    /// Aus „Kassenzettel prüfen“: Ignorierte und nicht bestätigte neue Zeilen behalten keinen Artikel.
    init(_ line: ReceiptReviewLine) {
        self.init(raw: line.raw, itemName: line.isSaved ? line.itemName : nil, price: line.price,
                  unitPrice: line.unitPrice, quantity: line.quantity, isSaved: line.isSaved)
    }
}
