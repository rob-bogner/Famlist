/*
 ReceiptLineContext.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Was die Anzeige gespeicherter Bons braucht: Nachschlagen fehlender Kategorien/Einheiten (ReceiptLineEnricher),
   Kategorien des Nutzers (Icons) und die Kategoriefarben über alle Bons (CategoryColorRanking).

 🔰 Notes for Beginners:
 - Nachgeschlagen wird nur in der geöffneten Liste, nicht im Artikelstamm: Der Artikelstamm liegt hinter einem
   asynchronen Repository, und Bon-Zeilen ohne Kategorie gibt es nur vom 28.09.2026 (Migration 029 → 030).
 - Nichts wird zurückgeschrieben; gespeicherte Werte eines Bons haben immer Vorrang.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptLineContext {
    let enricher: ReceiptLineEnricher
    let ranking: CategoryColorRanking

    static let empty = ReceiptLineContext(enricher: ReceiptLineEnricher(listItems: [], catalog: [],
                                                                        categories: CategoryDefinition.defaults),
                                          ranking: .empty)

    init(enricher: ReceiptLineEnricher, ranking: CategoryColorRanking) {
        self.enricher = enricher
        self.ranking = ranking
    }

    /// `receipts`: alle Bons des Archivs (für die Farben), `listItems`: Artikel der geöffneten Liste.
    init(receipts: [ArchivedReceipt], listItems: [ItemModel], categories: [CategoryDefinition]) {
        let enricher = ReceiptLineEnricher(listItems: listItems, catalog: [], categories: categories)
        self.enricher = enricher
        self.ranking = CategoryColorRanking.make(lines: receipts.flatMap { ($0.lines ?? []).map(enricher.enrich) })
    }

    var categories: [CategoryDefinition] { enricher.categories }

    /// Zeilen eines Bons mit ergänzten Kategorien und Einheiten.
    func lines(of receipt: ArchivedReceipt) -> [ReceiptLine] {
        (receipt.lines ?? []).map(enricher.enrich)
    }

    /// Kategorie-Definition zu einem Namen (für das Icon).
    func definition(named name: String?) -> CategoryDefinition? {
        guard let name else { return nil }
        return categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
