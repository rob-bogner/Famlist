/*
 PendingItemCheck.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein gerade abgehakter Artikel, dessen Haken noch per „Rückgängig“ entfernt werden kann.

 🔰 Notes for Beginners:
 - Anders als beim Löschen (PendingItemDeletion) ist der Haken sofort gespeichert und synchronisiert.
   „Rückgängig“ entfernt ihn über den normalen Weg wieder (neue HLC, gewinnt gegen das Abhaken).
 - Der Toast zeigt den Artikelnamen, weil der Artikel nach dem Abhaken zu den abgehakten wandert
   und der Nutzer ihn sonst nicht mehr sieht.

 📝 Last Change:
 - Initial creation (Wunsch Robert 12.10.2026: Rückgängig-Toast auch beim Abhaken).
 ------------------------------------------------------------------------
 */

import Foundation

/// Item that was just checked while the undo toast is visible.
struct PendingItemCheck: Equatable, Identifiable {
    let id = UUID()
    let listId: UUID
    let itemId: String
    let name: String
    /// Zeitpunkt, an dem der Toast ausgeblendet wird.
    let deadline: Date

    /// Gleiche Dauer wie beim Löschen (SPEC §3.4).
    static let undoDuration: TimeInterval = PendingItemDeletion.undoDuration

    /// Text im Toast: „„Milch“ abgehakt“.
    var message: String { "„\(name)“ abgehakt" }
}
