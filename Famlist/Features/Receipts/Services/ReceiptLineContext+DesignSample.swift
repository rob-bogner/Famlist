/*
 ReceiptLineContext+DesignSample.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kategorien und Farben der Boards (ReceiptDetailMeta, InsightSpend, InsightUsage) für Vorschauen und
   den Design-Modus der UI-Tests.

 🔰 Notes for Beginners:
 - Die Boards nutzen Kategorien, die es als Standard nicht gibt (Pflanzendrinks, Konserven, Süßes & Snacks,
   Fleisch & Wurst). Sie werden hier mit passenden Icons aus CategoryIconCatalog ergänzt.
 - Rang wie die Farben im Board: Pflanzendrinks wie Getränke (lila), Konserven wie Backwaren (orange; das Board
   hat dafür einen eigenen Ton #D07A4A, den der Auftrag nicht vorsieht).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

extension ReceiptLineContext {
    static let designCategories: [CategoryDefinition] = {
        let extra = [("Fleisch & Wurst", "meat"), ("Pflanzendrinks", "glass"), ("Konserven", "can"),
                     ("Süßes & Snacks", "chocolate")]
        let base = CategoryDefinition.defaults
        return base + extra.enumerated().map { index, pair in
            CategoryDefinition(id: UUID(), name: pair.0, icon: pair.1, position: base.count + index)
        }
    }()

    static let designSample = ReceiptLineContext(
        enricher: ReceiptLineEnricher(listItems: [], catalog: [], categories: designCategories),
        ranking: CategoryColorRanking(ranks: ["Obst & Gemüse": 0, "Milchprodukte": 1, "Fleisch & Wurst": 2,
                                              "Getränke": 3, "Pflanzendrinks": 3, "Backwaren": 4, "Konserven": 4,
                                              "Süßes & Snacks": 5]))
}
