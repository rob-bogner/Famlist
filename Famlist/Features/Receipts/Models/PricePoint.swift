/*
 PricePoint.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein gespeicherter Preis: Artikel, Laden, Einkaufsdatum, Preis (aus „Kassenzettel prüfen“ → „Preise speichern“).

 🔰 Notes for Beginners:
 - Preispunkte werden nur angelegt, nie geändert → keine Konflikte beim Synchronisieren.
 - `itemKey` = Artikelname klein geschrieben; damit findet der Preisverlauf alle Preise eines Artikels
   (der Artikelstamm ist ebenfalls pro Name eindeutig).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

struct PricePoint: Codable, Identifiable, Equatable {
    var id: UUID
    var itemKey: String
    var itemName: String
    var storeName: String
    var purchasedAt: Date
    var price: Decimal

    init(id: UUID = UUID(), itemName: String, storeName: String, purchasedAt: Date, price: Decimal) {
        self.id = id
        self.itemKey = Self.key(for: itemName)
        self.itemName = itemName
        self.storeName = storeName
        self.purchasedAt = purchasedAt
        self.price = price
    }

    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
