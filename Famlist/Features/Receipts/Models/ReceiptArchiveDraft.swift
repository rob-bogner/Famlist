/*
 ReceiptArchiveDraft.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Alles, was „Preise speichern“ für einen neuen Archiv-Eintrag liefert (Aufnahmen, Laden, Summe, …).

 🔰 Notes for Beginners:
 - `ReceiptArchive.archive(_:)` macht daraus Fotodateien und einen Auftrag in der Warteschlange.
 - `creatorName` und `listTitle` dienen nur der Anzeige, solange der Bon noch nicht hochgeladen ist.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import UIKit

struct ReceiptArchiveDraft {
    var pages: [UIImage]
    var listId: UUID
    var listTitle: String?
    var createdBy: UUID?
    var creatorName: String?
    var storeName: String
    var purchasedAt: Date
    var total: Decimal
    var lineCount: Int
    var savedPriceCount: Int
}
