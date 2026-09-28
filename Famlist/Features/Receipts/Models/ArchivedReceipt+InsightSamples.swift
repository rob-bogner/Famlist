/*
 ArchivedReceipt+InsightSamples.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Beispiel-Bons April–September 2026 mit den Zahlen der Boards InsightSpend und InsightUsage
   (Vorschauen, Design-Modus, Board-Test in ReceiptInsightsTests).

 🔰 Notes for Beginners:
 - September: 9 Einkäufe, 412,37 € (Edeka 4 × 158,20 €, Rewe 2 × 131,45 €, Lidl 2 × 88,17 €, dm 1 × 34,55 €);
   Kategorien Obst & Gemüse 96,40 · Milchprodukte 71,20 · Fleisch & Wurst 64,90 · Getränke 45,30 ·
   Backwaren 38,10 · Süßes & Snacks 29,80; der Rest jedes Bons (66,67 €) ist „Sonstiges“.
 - Verbrauch September: Milch 14 l, Eier 30, Bananen 4,2 kg, Brot 6, Hackfleisch 2 kg, Kaffee 2 kg, Butter 5 × 250 g.
 - April–August: ein Bon je Monat mit Summe laut Board (356, 389, 372, 401, 382 €) und den Mengen für den Verlauf.
 - Die Verteilung auf die Bons ist nachgerechnet: Jeder Bon ist mindestens so hoch wie seine Zeilen.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

extension ArchivedReceipt {
    private typealias L = (item: String, category: String, price: String, qty: Int, units: Double?, measure: String?)

    static let insightSamples: [ArchivedReceipt] = september + earlierMonths

    // MARK: - September

    private static let septemberStores: [(store: String, day: Int, total: String)] = [
        ("Edeka", 24, "43.00"), ("Edeka", 17, "47.00"), ("Edeka", 10, "30.00"), ("Edeka", 3, "38.20"),
        ("Rewe", 19, "80.00"), ("Rewe", 5, "51.45"), ("Lidl", 12, "43.00"), ("Lidl", 26, "45.17"), ("dm", 21, "34.55")
    ]

    /// Zeilen je Bon (Index wie `septemberStores`).
    private static let septemberLines: [[L]] = [
        [milk, eggs("1.79"), bread, ("Tomaten", obst, "9.95", 1, nil, nil), ("Joghurt", dairy, "5.49", 1, nil, nil),
         ("Salami", meat, "8.98", 1, nil, nil)],
        [milk, banana, ("Butter", dairy, "4.98", 2, 250, "g"), ("Erdbeeren", obst, "11.96", 1, nil, nil),
         ("Frischkäse", dairy, "3.49", 1, nil, nil), ("Würstchen", meat, "6.99", 1, nil, nil),
         ("Brötchen", bakery, "7.80", 1, nil, nil)],
        [milk, eggs("1.79"), ("Hackfleisch", meat, "4.49", 1, 0.5, "kg"), ("Gurken", obst, "6.45", 1, nil, nil),
         ("Quark", dairy, "3.99", 1, nil, nil), ("Tee", drinks, "3.44", 1, nil, nil)],
        [milk, banana, ("Salat", obst, "5.98", 1, nil, nil), ("Zucchini", obst, "6.69", 1, nil, nil),
         ("Skyr", dairy, "2.49", 1, nil, nil), ("Aufschnitt", meat, "6.00", 1, nil, nil),
         ("Croissants", bakery, "5.61", 1, nil, nil)],
        [milk, eggs("1.79"), bread, coffee, ("Äpfel", obst, "12.47", 1, nil, nil), ("Kartoffeln", obst, "8.99", 1, nil, nil),
         ("Käse", dairy, "8.99", 1, nil, nil), ("Hähnchenbrust", meat, "14.97", 1, nil, nil),
         ("Orangensaft", drinks, "5.98", 1, nil, nil)],
        [banana, ("Hackfleisch", meat, "4.50", 1, 0.5, "kg"), ("Butter", dairy, "7.47", 3, 250, "g"),
         ("Paprika", obst, "8.97", 1, nil, nil), ("Trauben", obst, "8.97", 1, nil, nil),
         ("Mozzarella", dairy, "4.29", 1, nil, nil), ("Schinken", meat, "9.98", 1, nil, nil)],
        [milk, eggs("1.80"), banana, ("Hackfleisch", meat, "8.99", 1, 1, "kg"), ("Karotten", obst, "4.47", 1, nil, nil),
         ("Sahne", dairy, "2.49", 1, nil, nil), ("Mineralwasser", drinks, "5.94", 1, nil, nil),
         ("Toast", bakery, "3.99", 1, nil, nil)],
        [milk, eggs("1.80"), bread, coffee, ("Zwiebeln", obst, "3.98", 1, nil, nil),
         ("Schmand", dairy, "1.89", 1, nil, nil), ("Apfelschorle", drinks, "3.96", 1, nil, nil)],
        [("Schokolade", sweets, "8.97", 1, nil, nil), ("Chips", sweets, "5.98", 1, nil, nil),
         ("Kekse", sweets, "6.87", 1, nil, nil), ("Gummibärchen", sweets, "3.99", 1, nil, nil),
         ("Nüsse", sweets, "3.99", 1, nil, nil)]
    ]

    private static let obst = "Obst & Gemüse", dairy = "Milchprodukte", meat = "Fleisch & Wurst"
    private static let drinks = "Getränke", bakery = "Backwaren", sweets = "Süßes & Snacks"
    private static let milk: L = ("Milch", dairy, "2.38", 2, 1, "l")
    private static let banana: L = ("Bananen", obst, "1.88", 1, 1.05, "kg")
    private static let bread: L = ("Brot", bakery, "6.90", 2, 1, "piece")
    private static let coffee: L = ("Kaffee", drinks, "12.99", 1, 1, "kg")
    private static func eggs(_ price: String) -> L { ("Eier", dairy, price, 1, 6, "piece") }

    private static var september: [ArchivedReceipt] {
        septemberStores.enumerated().map { index, entry in
            sample(index: 100 + index, store: entry.store, month: 9, day: entry.day, total: entry.total,
                   lines: septemberLines[index])
        }
    }

    // MARK: - April bis August

    /// (Monat, Summe, Milch l, Eier, Bananen kg, Brot, Hackfleisch kg, Kaffee kg, Butter Stück à 250 g)
    private static let history: [(Int, String, Double, Double, Double, Double, Double, Double, Int)] = [
        (4, "356.00", 10, 24, 3.0, 5, 2.5, 2, 3),
        (5, "389.00", 11, 30, 3.4, 6, 2.0, 2, 4),
        (6, "372.00", 10, 26, 4.1, 7, 2.0, 1, 4),
        (7, "401.00", 12, 30, 3.8, 6, 2.5, 2, 4),
        (8, "382.00", 12, 28, 3.8, 7, 2.5, 2, 4)
    ]

    private static var earlierMonths: [ArchivedReceipt] {
        history.map { h in
            let lines: [L] = [("Milch", dairy, "14.28", 1, h.2, "l"), ("Eier", dairy, "8.40", 1, h.3, "piece"),
                              ("Bananen", obst, "6.80", 1, h.4, "kg"), ("Brot", bakery, "20.70", Int(h.5), 1, "piece"),
                              ("Hackfleisch", meat, "22.45", 1, h.6, "kg"), ("Kaffee", drinks, "25.98", 1, h.7, "kg"),
                              ("Butter", dairy, "9.96", h.8, 250, "g")]
            return sample(index: 200 + h.0, store: h.0 % 2 == 0 ? "Rewe" : "Edeka", month: h.0, day: 15, total: h.1,
                          lines: lines)
        }
    }

    // MARK: - Bau

    private static func sample(index: Int, store: String, month: Int, day: Int, total: String,
                               lines: [L]) -> ArchivedReceipt {
        let id = UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index)) ?? UUID()
        let date = ReceiptTimes.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? Date()
        let receiptLines = lines.map { l in
            sampleLine(l.item.uppercased(), l.item, l.price, unitPrice(l.price, l.qty), l.qty, l.category, l.units, l.measure)
        }
        return ArchivedReceipt(id: id, listId: designListId, listTitle: "Wocheneinkauf", createdBy: nil, creatorName: "Rob",
                               storeName: store, purchasedAt: date, total: Decimal(string: total) ?? 0,
                               lineCount: receiptLines.count, savedPriceCount: receiptLines.count,
                               photoPaths: [photoPath(listId: designListId, receiptId: id, index: 1)],
                               bytes: 1_000_000, createdAt: date, lines: receiptLines)
    }

    private static func unitPrice(_ price: String, _ quantity: Int) -> String {
        let value = ParsedReceipt.unitPrice(price: Decimal(string: price) ?? 0, quantity: quantity)
        return "\(value)"
    }
}
