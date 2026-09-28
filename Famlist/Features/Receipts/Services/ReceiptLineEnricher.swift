/*
 ReceiptLineEnricher.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergänzt Bon-Zeilen um Kategorie, Einheit, Inhalt je Stück und Artikel-ID des zugeordneten Artikels.
   Beim Speichern (neue Bons) und beim Anzeigen (ältere Bons ohne diese Felder, ohne Zurückschreiben).

 🔰 Notes for Beginners:
 - Gesucht wird über den Artikelnamen (klein geschrieben, wie CatalogOperation.key): zuerst in der Liste,
   dann im Artikelstamm. Der Artikelstamm kennt keine Menge, also auch keinen Inhalt je Stück.
 - Inhalt je Stück = Listenmenge ÷ Stückzahl auf dem Bon (Entscheidung Robert 29.09.2026: Die Listenmenge
   ist die Gesamtmenge). „Schokolade 200 g“ auf der Liste und „2 ×“ auf dem Bon → 100 g je Stück.
 - Kategorie wird über CategoryResolver auf die Kategorien des Nutzers abgebildet (unbekannt → „Sonstiges“).
 - Vorhandene Werte einer Zeile werden nie überschrieben.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptLineEnricher {
    /// Was über einen Artikel bekannt ist.
    struct Article: Equatable {
        let id: String
        let category: String?
        /// Menge auf der Liste (nil = aus dem Artikelstamm, dort gibt es keine Menge).
        let amount: Double?
        let measure: String
    }

    /// Artikel je Name-Schlüssel; Einträge der Liste haben Vorrang vor dem Artikelstamm.
    let articles: [String: Article]
    let categories: [CategoryDefinition]

    init(listItems: [ItemModel], catalog: [ItemCatalogEntry], categories: [CategoryDefinition]) {
        var map: [String: Article] = [:]
        for entry in catalog {
            map[CatalogOperation.key(entry.name)] = Article(id: entry.id, category: entry.category, amount: nil,
                                                            measure: entry.measure)
        }
        for item in listItems {
            map[CatalogOperation.key(item.name)] = Article(id: item.id, category: item.category, amount: item.units,
                                                           measure: item.measure)
        }
        self.articles = map
        self.categories = categories
    }

    func article(named name: String?) -> Article? {
        name.flatMap { articles[CatalogOperation.key($0)] }
    }

    /// Fehlende Felder einer zugeordneten Zeile ergänzen; nicht zugeordnete Zeilen bleiben unverändert.
    func enrich(_ line: ReceiptLine) -> ReceiptLine {
        guard line.itemName != nil, let article = article(named: line.itemName) else { return line }
        var copy = line
        if copy.category == nil { copy.category = CategoryResolver.name(for: article.category, in: categories) }
        if copy.measure == nil, !article.measure.isEmpty { copy.measure = article.measure }
        if copy.units == nil { copy.units = Self.unitsPerPiece(amount: article.amount, quantity: line.quantity) }
        if copy.itemId == nil { copy.itemId = article.id }
        return copy
    }

    /// Listenmenge ÷ Stückzahl, ungerundet (Stückzahl × Inhalt ergibt so wieder genau die Listenmenge).
    /// nil ohne Listenmenge.
    static func unitsPerPiece(amount: Double?, quantity: Int) -> Double? {
        guard let amount, amount > 0 else { return nil }
        return amount / Double(max(quantity, 1))
    }
}
