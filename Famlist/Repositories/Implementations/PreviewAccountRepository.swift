/*
 PreviewAccountRepository.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - AccountRepository ohne Server für Vorschauen und die UI-Test-Fixture (Konto-Archiv).

 🔰 Notes for Beginners:
 - Das Konto ist immer aktiv (status() = nil); archivierte Mitglieder und Hinweise kommen aus dem Initialisierer,
   z. B. „Sofie“ wie im Board ShareMembersArchived.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

final class PreviewAccountRepository: AccountRepository {
    private let archived: [ArchivedListMember]
    private let notices: [AccountNotice]

    init(archivedMembers: [ArchivedListMember] = [], notices: [AccountNotice] = []) {
        self.archived = archivedMembers
        self.notices = notices
    }

    /// Beispiel aus dem Board: „Sofie“, wiederherstellbar bis in 60 Tagen.
    static let designMember = ArchivedListMember(id: UUID(), name: "Sofie", purgeAfter: Date().addingTimeInterval(60 * 86_400))

    func status() async throws -> AccountArchiveStatus? { nil }
    func restore() async throws -> Bool { false }
    func purge() async throws {}
    func archivedMembers(listId: UUID) async throws -> [ArchivedListMember] { archived }
    func removeArchivedMember(listId: UUID, profileId: UUID) async throws {}
    func unseenNotices() async throws -> [AccountNotice] { notices }
    func markNoticeSeen(_ id: UUID) async throws {}
}
