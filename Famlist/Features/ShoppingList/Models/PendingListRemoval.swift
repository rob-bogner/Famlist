/*
 PendingListRemoval.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Liste, die gerade gelöscht bzw. verlassen wurde und 5 s lang per „Rückgängig“ zurückgeholt werden kann.

 🔰 Notes for Beginners:
 - Design: MyListsUndo („„Drogerie“ gelöscht“ + Rückgängig, Restzeit-Balken).
 - Die Liste ist sofort aus „Meine Listen“ verschwunden; erst nach Ablauf geht der Auftrag an den Server.
 - `wasActive`: war es die geöffnete Liste? Dann wechselt „Rückgängig“ auch wieder zu ihr.

 📝 Last Change:
 - Initial creation (Wisch-Aktionen „Meine Listen“ + Rückgängig).
 ------------------------------------------------------------------------
 */

import Foundation

/// A list hidden from "Meine Listen" while the undo toast is visible.
struct PendingListRemoval: Equatable, Identifiable {
    enum Kind: Equatable {
        /// Eigene Liste löschen (für alle Mitglieder).
        case delete
        /// Geteilte Liste verlassen (nur die eigene Mitgliedschaft).
        case leave(profileId: UUID)
    }

    let id = UUID()
    let list: ListModel
    let kind: Kind
    let wasActive: Bool
    /// Zeitpunkt, an dem der Toast verschwindet und der Auftrag gesendet wird.
    let deadline: Date

    /// Gleiche Dauer wie beim Löschen von Artikeln.
    static let undoDuration: TimeInterval = PendingItemDeletion.undoDuration

    /// Text im Hinweis, z. B. „„Drogerie“ gelöscht“.
    var message: String {
        switch kind {
        case .delete: return "„\(list.title)“ gelöscht"
        case .leave: return "„\(list.title)“ verlassen"
        }
    }
}
