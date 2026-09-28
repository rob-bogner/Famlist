/*
 ReceiptLineDisplay.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Artikelzeile im Bon-Detail, fertig zum Anzeigen (ReceiptLineRow).

 🔰 Notes for Beginners:
 - `itemName` ist nil, wenn die Bon-Zeile keinem Artikel zugeordnet ist; dann ist die Zeile nicht tippbar.
 - `rank` bestimmt die Kategoriefarbe (InsightPalette); nil = grau („Sonstiges“, „Ohne Kategorie“).
 - `category` liefert das Icon der Kachel (CategoryIconCatalog); nil = Icon von „Sonstiges“.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptLineDisplay: Identifiable, Equatable {
    let id: Int
    /// Zugeordneter Artikel, sonst Bon-Text.
    let name: String
    /// „1 × 250 g · je 2,49 €“.
    let detail: String
    /// Kategorie-Name oder „Ohne Kategorie“.
    let categoryName: String
    let category: CategoryDefinition?
    let rank: Int?
    /// „2,49 €“.
    let amount: String
    let itemName: String?

    static let noCategory = "Ohne Kategorie"
}
