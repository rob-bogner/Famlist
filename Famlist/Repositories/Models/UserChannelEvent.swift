/*
 UserChannelEvent.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ereignisse auf dem privaten Realtime-Kanal `user:<id>` (Trigger und RPCs der Migrationen 014 und 027).

 🔰 Notes for Beginners:
 - memberRemoved: Du wurdest aus einer Liste entfernt (oder deren Besitzer hat sein Konto gelöscht).
 - memberRestored: Der Besitzer hat sein Konto wiederhergestellt; du bist wieder Mitglied.
 - memberArchived: Ein Mitglied deiner Liste hat sein Konto gelöscht (Hinweis für den Besitzer).
 - accountArchived: Dein eigenes Konto wurde (auf einem anderen Gerät) gelöscht.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

enum UserChannelEvent: Equatable, Sendable {
    case memberRemoved(listId: UUID)
    case memberRestored(listId: UUID)
    case memberArchived(AccountNotice)
    case accountArchived
}
