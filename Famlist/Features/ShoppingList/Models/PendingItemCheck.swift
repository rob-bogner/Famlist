/*
 PendingItemCheck.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gerade abgehakte Artikel (einer oder mehrere), deren Haken noch per „Rückgängig“ entfernt werden kann.

 🔰 Notes for Beginners:
 - Anders als beim Löschen (PendingItemDeletion) ist der Haken sofort gespeichert und synchronisiert.
   „Rückgängig“ entfernt ihn über den normalen Weg wieder (neue HLC, gewinnt gegen das Abhaken).
 - Bei einem Artikel zeigt der Toast den Namen, weil der Artikel nach dem Abhaken zu den abgehakten wandert
   und der Nutzer ihn sonst nicht mehr sieht. Bei mehreren („Alle abhaken“) zeigt er die Anzahl.

 📝 Last Change:
 - Mehrere Artikel für „Alle abhaken“ im Dock und im Abschnittskopf (12.10.2026).
 - Initial creation (Wunsch Robert 12.10.2026: Rückgängig-Toast auch beim Abhaken).
 ------------------------------------------------------------------------
 */

import Foundation

/// Items that were just checked while the undo toast is visible.
struct PendingItemCheck: Equatable, Identifiable {
    let id = UUID()
    let listId: UUID
    /// Artikel, die durch diese Aktion abgehakt wurden (vorher offen).
    let itemIds: [String]
    /// Name des Artikels, wenn es genau einer ist.
    let name: String?
    /// Zeitpunkt, an dem der Toast ausgeblendet wird.
    let deadline: Date

    init(listId: UUID, items: [ItemModel], deadline: Date) {
        self.listId = listId
        self.itemIds = items.map(\.id)
        self.name = items.count == 1 ? items[0].name : nil
        self.deadline = deadline
    }

    var count: Int { itemIds.count }

    /// Gleiche Dauer wie beim Löschen (SPEC §3.4).
    static let undoDuration: TimeInterval = PendingItemDeletion.undoDuration

    /// Text im Toast: „„Milch“ abgehakt“ bzw. „16 Artikel abgehakt“.
    var message: String {
        if let name { return "„\(name)“ abgehakt" }
        return "\(count) Artikel abgehakt"
    }
}
