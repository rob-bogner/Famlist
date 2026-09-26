/*
 ArchivedReceipt.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein gespeicherter Kassenzettel im Archiv: Laden, Datum, Summe, Zähler und die Pfade der Fotos
   (Tabelle `receipts`, Bucket `receipt-images`, Migration 021).

 🔰 Notes for Beginners:
 - Ein Bon ändert sich nach dem Speichern nicht mehr; er wird nur angelegt oder gelöscht.
 - `listTitle` und `creatorName` kommen beim Laden vom Server mit (für die Anzeige im Archiv).
 - `isPending`: liegt nur lokal in der Warteschlange und ist noch nicht hochgeladen.
 - Fotopfade `<list_id>/<receipt_id>/<n>.jpg` in Kleinbuchstaben: Die Zugriffsregel vergleicht mit
   `list_id::text`, und Postgres schreibt UUIDs klein.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

struct ArchivedReceipt: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let listId: UUID
    var listTitle: String?
    var createdBy: UUID?
    var creatorName: String?
    let storeName: String
    let purchasedAt: Date
    let total: Decimal
    let lineCount: Int
    let savedPriceCount: Int
    let photoPaths: [String]
    let bytes: Int
    let createdAt: Date
    var isPending = false

    /// Pfad des n-ten Fotos (1-basiert) im Bucket.
    static func photoPath(listId: UUID, receiptId: UUID, index: Int) -> String {
        "\(listId.uuidString.lowercased())/\(receiptId.uuidString.lowercased())/\(index).jpg"
    }

    /// „G“ für den Avatar; „?“, wenn der Name unbekannt ist (z. B. Konto gelöscht).
    var creatorInitial: String {
        guard let first = creatorName?.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(first).uppercased()
    }
}
