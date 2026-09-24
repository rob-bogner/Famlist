/*
 ReceiptReviewLine.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Bon-Position in „Kassenzettel prüfen“: Bon-Text, Preis, zugeordneter Artikel und Status.

 🔰 Notes for Beginners:
 - Status wie im Design: „Zugeordnet“ (grün), „Zuordnung prüfen“ (gelb), „Neuer Artikel?“ (Akzent).
 - `ignored` = Nutzer hat die Position verworfen (z. B. Tüte); sie zählt nicht zu den gespeicherten Preisen.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptReviewLine: Identifiable, Equatable {
    let id: UUID
    let raw: String
    let price: Decimal
    /// Zugeordneter Artikelname; bei „Neuer Artikel?“ der Vorschlag aus dem Bon-Text.
    var itemName: String?
    var status: ReceiptItemMatcher.Status
    var ignored = false

    /// Wird beim Speichern berücksichtigt: zugeordnet/geprüft, oder vom Nutzer als neuer Artikel bestätigt.
    var confirmedNew = false
    var isSaved: Bool { !ignored && itemName != nil && (status != .new || confirmedNew) }
}
