/*
 InvitePreviewInfo.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeige-Daten für „Einladung annehmen“: wer einlädt, welche Liste, wie viele Artikel und Mitglieder.

 📝 Last Change:
 - Einladungen mit Token (Migration 014): Vorschau gehört zu einem Token, nicht mehr zu einer Listen-ID.
 ------------------------------------------------------------------------
 */

import Foundation

struct InvitePreviewInfo: Equatable {
    /// Token des Links, zu dem diese Vorschau gehört.
    let token: String
    /// nil = Vorschau nicht geladen (offline) oder Einladung ungültig.
    let listId: UUID?
    /// nil = unbekannt; die Ansicht zeigt dann „Jemand“.
    let inviterName: String?
    let listName: String
    /// nil = nicht bekannt (offline); die Chips entfallen dann.
    let itemCount: Int?
    let memberCount: Int?
}
