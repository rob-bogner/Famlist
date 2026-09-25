/*
 ShareMembersViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lädt Besitzer und Mitglieder einer Liste für „Mitglieder & Teilen“, entfernt Mitglieder (nur Besitzer).

 🔰 Notes for Beginners:
 - list_members enthält nur Mitglieder ohne Besitzer; den Besitzer lädt `profile(id:)`.
 - Man selbst erscheint als „Name (Du)“ wie im Design („Rob (Du)“).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4). Ersetzt MembersView und ShareListView.
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ShareMembersViewModel: ObservableObject {
    @Published private(set) var members: [ShareMember] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let list: ListModel
    private let me: Profile?
    private let lists: ListsRepository?
    private let profiles: ProfilesRepository?

    init(list: ListModel, me: Profile?, lists: ListsRepository?, profiles: ProfilesRepository?) {
        self.list = list
        self.me = me
        self.lists = lists
        self.profiles = profiles
        members = [ownerRow(name: me.map(\.displayName))].compactMap { $0 }
    }

    var isOwner: Bool { list.ownerId == me?.id }

    var inviteURL: URL? {
        guard let me else { return nil }
        return InviteLink.url(listId: list.id, listTitle: list.title, inviterPublicId: me.publicId)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
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

    private func ownerRow(name: String?) -> ShareMember? {
        guard isOwner else { return nil }
        return ShareMember(id: list.ownerId, name: "\(name ?? "Du") (Du)", role: "Besitzer", isOwner: true, isMe: true)
    }
}
