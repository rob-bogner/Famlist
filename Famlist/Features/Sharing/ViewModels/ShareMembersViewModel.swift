/*
 ShareMembersViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lädt Besitzer und Mitglieder einer Liste für „Mitglieder & Teilen“, entfernt Mitglieder (nur Besitzer).
 - Archivierte Mitglieder (Konto gelöscht, noch wiederherstellbar) zeigt und entfernt nur der Besitzer.

 🔰 Notes for Beginners:
 - list_members enthält nur Mitglieder ohne Besitzer; den Besitzer lädt `profile(id:)`.
 - Man selbst erscheint als „Name (Du)“ wie im Design („Rob (Du)“).

 📝 Last Change:
 - Archivierte Mitglieder anzeigen und entfernen (Konto-Archiv, 27.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ShareMembersViewModel: ObservableObject {
    @Published private(set) var members: [ShareMember] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Einladungslink mit Token (Migration 014). nil, bis der Server ihn geliefert hat (offline: bleibt nil).
    @Published private(set) var inviteURL: URL?
    /// Mitglieder mit gelöschtem Konto, die noch wiederherstellen können (nur für den Besitzer, Migration 027).
    @Published private(set) var archivedMembers: [ArchivedListMember] = []

    let list: ListModel
    private let me: Profile?
    private let lists: ListsRepository?
    private let profiles: ProfilesRepository?
    private let accounts: AccountRepository?

    init(list: ListModel, me: Profile?, lists: ListsRepository?, profiles: ProfilesRepository?,
         accounts: AccountRepository? = nil) {
        self.list = list
        self.me = me
        self.lists = lists
        self.profiles = profiles
        self.accounts = accounts
        members = [ownerRow(name: me.map(\.displayName))].compactMap { $0 }
    }

    var isOwner: Bool { list.ownerId == me?.id }

    /// Zahl für „Mitglieder · N“: aktive und archivierte (Board ShareMembersArchived).
    var memberCount: Int { members.count + archivedMembers.count }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await loadInviteURL(reportErrors: false)
        var rows: [ShareMember] = []
        if isOwner {
            rows.append(ShareMember(id: list.ownerId, name: "\(me?.displayName ?? "Du") (Du)", role: "Besitzer",
                                    isOwner: true, isMe: true))
        } else if let owner = try? await profiles?.profile(id: list.ownerId) {
            rows.append(ShareMember(id: owner.id, name: owner.displayName, role: "Besitzer", isOwner: true, isMe: false))
        }
        do {
            let others = try await lists?.fetchMembers(listId: list.id) ?? []
            rows += others.map { m in
                let isMe = m.id == me?.id
                return ShareMember(id: m.id, name: isMe ? "\(m.displayName) (Du)" : m.displayName, role: "Mitglied",
                                   isOwner: false, isMe: isMe)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Mitglieder konnten nicht geladen werden."
        }
        members = rows
        if isOwner, let archived = try? await accounts?.archivedMembers(listId: list.id) {
            archivedMembers = archived
        }
    }

    /// Besitzer entfernt ein Mitglied mit gelöschtem Konto endgültig (kommt beim Wiederherstellen nicht zurück).
    func removeArchived(_ member: ArchivedListMember) {
        guard isOwner, let accounts else { return }
        let previous = archivedMembers
        archivedMembers.removeAll { $0.id == member.id }
        UserLog.Data.archivedMemberRemoved(name: member.name)
        Task {
            do {
                try await accounts.removeArchivedMember(listId: list.id, profileId: member.id)
            } catch {
                archivedMembers = previous
                errorMessage = "„\(member.name)“ konnte nicht entfernt werden."
            }
        }
    }

    /// Besitzer entfernt ein Mitglied (Wischen).
    func remove(_ member: ShareMember) {
        guard isOwner, !member.isOwner, let lists else { return }
        let previous = members
        members.removeAll { $0.id == member.id }
        UserLog.Data.memberRemoved(name: member.name)
        Task {
            do {
                try await lists.removeMember(listId: list.id, profileId: member.id)
            } catch {
                members = previous
                errorMessage = "„\(member.name)“ konnte nicht entfernt werden."
            }
        }
    }

    /// Tippt der Nutzer auf „teilen“/„kopieren“, bevor der Link da ist (z. B. offline beim Öffnen):
    /// erneut versuchen und bei Fehlschlag einen Hinweis zeigen.
    func ensureInviteURL() async {
        await loadInviteURL(reportErrors: true)
    }

    /// Nutzer hat den Einladungslink kopiert (Protokoll für die Nutzer-Logs).
    func noteInviteLinkCopied() {
        UserLog.Data.inviteLinkCopied(listName: list.title)
    }

    /// Holt den Einladungs-Token beim Server. Ohne Verbindung bleibt der Link aus.
    private func loadInviteURL(reportErrors: Bool) async {
        guard inviteURL == nil, let lists else { return }
        do {
            let token = try await lists.createInvite(listId: list.id)
            inviteURL = InviteLink.url(token: token, listTitle: list.title)
        } catch {
            logVoid(params: (action: "loadInviteURL.error", error: (error as NSError).localizedDescription))
            if reportErrors { errorMessage = InviteError.unavailable.errorDescription }
        }
    }

    private func ownerRow(name: String?) -> ShareMember? {
        guard isOwner else { return nil }
        return ShareMember(id: list.ownerId, name: "\(name ?? "Du") (Du)", role: "Besitzer", isOwner: true, isMe: true)
    }
}
