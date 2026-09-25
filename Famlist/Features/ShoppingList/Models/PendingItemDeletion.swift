/*
 PendingItemDeletion.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Löschung aus dem Dock („Nur abgehakte“ / „Alle Artikel“), die noch rückgängig gemacht werden kann.

 🔰 Notes for Beginners:
 - Die Artikel verschwinden sofort aus der Anzeige, gelöscht wird erst nach Ablauf des Toasts (5 s).
   Grund: Ein Tombstone gewinnt im Konfliktlöser immer, und die Artikel-ID ist deterministisch.
   Ein „Wiederherstellen“ NACH dem Löschen würde der Sync wieder überschreiben.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Dock „Löschen“ + Rückgängig).
 ------------------------------------------------------------------------
 */

import Foundation

/// Items hidden from the list while the undo toast is visible.
struct PendingItemDeletion: Equatable, Identifiable {
    let id = UUID()
    let listId: UUID
    let items: [ItemModel]
    /// Zeitpunkt, an dem der Toast ausgeblendet und die Löschung geschrieben wird.
    let deadline: Date

    /// Dauer des Rückgängig-Toasts laut SPEC §3.4.
    static let undoDuration: TimeInterval = 5

    var count: Int { items.count }
}
