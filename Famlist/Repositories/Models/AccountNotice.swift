/*
 AccountNotice.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gespeicherter Hinweis für den Listenbesitzer: „<Name> hat das Konto gelöscht“ (Tabelle account_notices,
   Migration 027).

 🔰 Notes for Beginners:
 - Der Server legt den Hinweis an, wenn ein Mitglied sein Konto löscht, und schickt zusätzlich ein
   Realtime-Ereignis. War der Besitzer offline, holt die App den Hinweis beim nächsten Start nach.
 - Nach dem Anzeigen markiert die App ihn als gesehen (mark_notice_seen); er erscheint nur einmal.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

struct AccountNotice: Identifiable, Hashable, Sendable {
    let id: UUID
    let listId: UUID?
    let subjectName: String
}
