/*
 InviteAcceptView.swift

 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet das erscheint, wenn ein Nutzer einen Einladungs-Deep-Link öffnet (FAM-31).
 - Lädt das Profil des Einladenden und zeigt Listentitel + Einladenden-Name.
 - Zwei Aktionen: Beitreten oder Ablehnen.

 📝 Last Change:
 - FAM-21: Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Zeigt eine Einladung zum Beitreten einer geteilten Liste.
struct InviteAcceptView: View {
    let invite: AppSessionViewModel.InvitePayload

    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inviterName: String? = nil
    @State private var isLoadingProfile = true

    var body: some View {
        CustomModalView(title: "Einladung", onClose: {
            session.pendingInvite = nil
        }) {
            VStack(spacing: 20) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(Color.accentColor)
                    .padding(.top, 24)

                if isLoadingProfile {
                    ProgressView()
                } else {
                    VStack(spacing: 8) {
                        if let name = inviterName {
                            Text("\(name) lädt dich ein")
                                .font(.headline)
                        } else {
                            Text("Du wurdest eingeladen")
                                .font(.headline)
                        }

                        if !invite.listTitle.isEmpty {
                            Text("zur Liste \"\(invite.listTitle)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "Beitreten") {
                        session.acceptInvite(invite)
                    }
                    .padding(.horizontal)

                    Button("Ablehnen") {
                        session.pendingInvite = nil
                    }
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            await loadInviterProfile()
        }
    }

    private func loadInviterProfile() async {
        defer { isLoadingProfile = false }
        do {
            if let profile = try await session.profiles.profileByPublicId(invite.inviterPublicId) {
                inviterName = profile.fullName ?? profile.username ?? profile.publicId
            }
        } catch {
            logVoid(params: (action: "InviteAcceptView.loadInviterProfile.error",
                             error: (error as NSError).localizedDescription))
        }
    }
}
