/*
 InvitePreviewInfo.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeige-Daten für „Einladung annehmen“: wer einlädt, welche Liste, wie viele Artikel und Mitglieder.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

struct InvitePreviewInfo: Equatable {
    let listId: UUID
    let inviterName: String
    let listName: String
    /// nil = nicht bekannt (offline); die Chips entfallen dann.
    let itemCount: Int?
    let memberCount: Int?
}
