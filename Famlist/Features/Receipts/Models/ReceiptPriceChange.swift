/*
 ReceiptPriceChange.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein neuer Artikelpreis aus dem Kassenzettel: Artikelname und Preis je Stück.

 🔰 Notes for Beginners:
 - Entsteht in „Kassenzettel prüfen“, wenn der Bon-Preis vom gespeicherten Artikelpreis abweicht.
 - Übernimmt der Nutzer die Preise, setzt ListViewModel.applyReceiptPrices den Preis bei allen
   gleichnamigen Artikeln der Liste und im Artikelstamm (Name ohne Groß/klein und Rand-Leerzeichen).

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptPriceChange: Equatable {
    /// Artikelname wie zugeordnet, z. B. „Kerrygold, original irische Butter“.
    let name: String
    /// Preis je Stück in Euro (ItemModel.price ist Double).
    let price: Double

    var key: String { CatalogOperation.key(name) }
}
