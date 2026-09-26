/*
 ArchivedReceipt+DesignSamples.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Beispiel-Bons aus ReceiptArchive.dc.html / ReceiptDetail.dc.html für Vorschauen und den Design-Modus
   der UI-Tests (Screenshot-Vergleich).

 🔰 Notes for Beginners:
 - Sichtbar sind im Design fünf Bons (September und August 2026); die Unterzeile nennt „12 Bons · 38 MB“.
   Die übrigen sieben liegen weiter unten (Juli und Juni) und ergänzen Anzahl und Größe.
 - Nur Läden aus den Filterchips (Edeka, Rewe, Lidl, dm), damit die Chip-Reihe dem Design entspricht.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

extension ArchivedReceipt {
    static let designListId = UUID(uuidString: "00000000-0000-0000-0000-00000000B0B0") ?? UUID()

    /// Bytes je Bon, zusammen 38.000.000 („38 MB“).
    private static let sampleBytes = 38_000_000 / 12

    static let designSamples: [ArchivedReceipt] = {
        let rows: [(String, Int, Int, String, Int, String, String, String, Int)] = [
            ("Edeka", 2026, 9, "24", 5, "11.51", "Liste Edeka", "Rob", 2),
            ("Rewe", 2026, 9, "19", 23, "64.87", "Wocheneinkauf", "Anna", 1),
            ("Lidl", 2026, 9, "12", 17, "41.20", "Wocheneinkauf", "Rob", 1),
            ("Edeka", 2026, 8, "29", 9, "27.34", "Liste Edeka", "Anna", 1),
            ("dm", 2026, 8, "21", 6, "18.95", "Drogerie", "Rob", 1),
            ("Rewe", 2026, 7, "30", 14, "38.12", "Wocheneinkauf", "Rob", 1),
            ("Lidl", 2026, 7, "22", 11, "29.80", "Wocheneinkauf", "Anna", 1),
            ("Edeka", 2026, 7, "15", 7, "19.46", "Liste Edeka", "Rob", 1),
            ("dm", 2026, 7, "3", 4, "12.35", "Drogerie", "Anna", 1),
            ("Rewe", 2026, 6, "27", 19, "52.10", "Wocheneinkauf", "Rob", 2),
            ("Lidl", 2026, 6, "18", 12, "33.64", "Wocheneinkauf", "Anna", 1),
            ("Edeka", 2026, 6, "6", 8, "21.09", "Liste Edeka", "Rob", 1)
        ]
        return rows.enumerated().map { index, r in
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1)) ?? UUID()
            let date = Calendar.current.date(from: DateComponents(year: r.1, month: r.2, day: Int(r.3), hour: 12)) ?? Date()
            let paths = (1...r.8).map { photoPath(listId: designListId, receiptId: id, index: $0) }
            return ArchivedReceipt(id: id, listId: designListId, listTitle: r.6, createdBy: nil, creatorName: r.7,
                                   storeName: r.0, purchasedAt: date, total: Decimal(string: r.5) ?? 0,
                                   lineCount: r.4, savedPriceCount: r.4, photoPaths: paths,
                                   bytes: sampleBytes + (index == 0 ? 38_000_000 % 12 : 0), createdAt: date)
        }
    }()
}
