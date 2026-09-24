/*
 MembersView.swift

 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet mit allen Mitgliedern einer geteilten Liste (FAM-33).
 - Owner kann Mitglieder per Swipe-Delete entfernen.

 📝 Last Change:
 - FAM-21: Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Zeigt alle Kollaboratoren einer Liste; Owner kann Mitglieder entfernen.
struct MembersView: View {
    let list: ListModel?

    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var members: [ListMember] = []
    @State private var isLoading = true
    @State private var error: String? = nil

    private var isOwner: Bool { list?.ownerId == session.currentProfile?.id }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    var body: some View {
        CustomModalView(title: "Mitglieder", onClose: { dismiss() }) {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 40)
                } else if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else if members.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Keine Mitglieder")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Teile die Liste, um Familienmitglieder einzuladen.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    SwiftUI.List {
                        ForEach(members) { member in
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName)
                                        .font(.body)
                                    Text("Beigetreten: \(Self.dateFormatter.string(from: member.addedAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: isOwner ? removeMember : nil)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            await loadMembers()
        }
    }

    private func loadMembers() async {
        guard let listId = list?.id else {
            isLoading = false
            return
        }
        do {
            members = try await session.lists.fetchMembers(listId: listId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            logVoid(params: (action: "MembersView.loadMembers.error",
                             error: (error as NSError).localizedDescription))
        }
    }

    private func removeMember(at offsets: IndexSet) {
        guard let listId = list?.id else { return }
        let toRemove = offsets.map { members[$0] }
        members.remove(atOffsets: offsets)
        for member in toRemove {
            Task {
                do {
                    try await session.lists.removeMember(listId: listId, profileId: member.id)
                } catch {
                    // Rollback: re-add member locally
                    await MainActor.run {
                        members.append(member)
                        members.sort { $0.addedAt < $1.addedAt }
                    }
                    logVoid(params: (action: "MembersView.removeMember.error",
                                     error: (error as NSError).localizedDescription))
                }
            }
        }
    }
}
