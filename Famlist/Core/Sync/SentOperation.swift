/*
 SentOperation.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unveränderliche Kopie einer gesendeten SyncOperation. SwiftData-Objekte können während des Wartens
   auf den Server gelöscht werden (Abmelden, Liste vergessen); danach dürfen ihre Felder nicht mehr
   gelesen werden (Audit 2, Befund S5).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

/// Kopie der Felder einer gesendeten Operation (siehe `send`): nach dem Warten auf den Server gefahrlos lesbar.
struct SentOperation {
    let id: UUID
    let itemId: String
    let retryCount: Int

    init(_ operation: SyncOperation) {
        id = operation.id
        itemId = operation.itemId
        retryCount = operation.retryCount
    }
}
