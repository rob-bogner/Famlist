/*
 AcceptInviteView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Screen „Einladung annehmen“: Hero, Karte mit Avatar des Einladenden, Listenname, Artikel- und
   Mitgliederzahl, „Einladung annehmen“ / „Ablehnen“.

 🔰 Notes for Beginners:
 - Vorlage: AcceptInviteScreen in design-handoff/MyListUI/Screens/OnboardingScreens.swift (AcceptInvite.dc.html).
 - Die Zahlen kommen aus der RPC invite_preview (Migration 010); ohne Verbindung entfallen die Chips.
 - Annehmen trägt den Nutzer als Mitglied ein und öffnet die Liste sofort.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5). Ersetzt InviteAcceptView (System-Sheet).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct AcceptInviteView: View {
    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.colorScheme) private var colorScheme
    let invite: AppSessionViewModel.InvitePayload
    @State private var isAccepting = false

    var body: some View {
        let appearance = Appearance(colorScheme)
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        let bodyFont = AppFont.ui(.dmSans, 14, 400)
        let info = session.invitePreview
        let inviterName = info?.inviterName ?? invite.inviterPublicId
        let listName = info?.listName ?? invite.listTitle

        ZStack(alignment: .top) {
            EKKScreenBackground(t: t)

            EKKHero(t: t, height: 360) { EmptyView() }

            VStack(spacing: 10) {
                // Avatar: Verlauf über die ganze Border-Box, Rahmen 4 in ringBase darüber
                Text(String(inviterName.prefix(1)).uppercased())
                    .font(AppFont.outfit(28, 600))
                    .foregroundStyle(Color.white)
                    .frame(width: 80, height: 80)
                    .background(CSSBox(shape: Circle(), paint: t.avatarBg, border: 4, borderColor: t.ringBase))
                    .padding(.top, -64)
                    .accessibilityHidden(true)

                (Text(inviterName).font(AppFont.dm(15, 600)).foregroundStyle(k.text)
                    + Text(" lädt dich ein zur Liste"))
                    .font(AppFont.dm(15, 400))
                    .foregroundStyle(k.sub)
                    .multilineTextAlignment(.center)

                Text(listName)
                    .font(AppFont.outfit(30, 700))
                    .tracking(-0.6)                                          // -0.02em × 30
                    .foregroundStyle(k.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if let items = info?.itemCount, let members = info?.memberCount {
                    HStack(spacing: 8) {
                        inviteChip(items == 1 ? "1 Artikel" : "\(items) Artikel", k: k, t: t)
                        inviteChip(members == 1 ? "1 Mitglied" : "\(members) Mitglieder", k: k, t: t)
                    }
                    .padding(.top, 2)
                }

                Text("Ihr seht Änderungen sofort – wer etwas hinzufügt oder abhakt, sehen alle Mitglieder.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(k.sub)
                    .multilineTextAlignment(.center)
                    .cssLineHeight(21, font: bodyFont)                       // line-height 1.5
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                VStack(spacing: 8) {
                    CTAButton(title: isAccepting ? "Wird beigetreten …" : "Einladung annehmen", k: k,
                              isEnabled: !isAccepting, action: accept)
                    EKKTextButton(title: "Ablehnen", color: k.sub, action: session.declineInvite)
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 29)                  // 1 Rahmen + 28 Padding
            .padding(.horizontal, 23)           // 1 Rahmen + 22 Padding
            .padding(.bottom, 23)
            .background(CSSBox(shape: RR(30), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
            .padding(.horizontal, 24)
            .padding(.top, 150)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task {
            if session.invitePreview?.listId != invite.listId { await session.loadInvitePreview(invite) }
        }
    }

    /// Chip: Padding 6 / 12, Pille, 13/600 in Akzent.
    private func inviteChip(_ text: String, k: SheetTheme, t: EKKTokens) -> some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .foregroundStyle(k.accentText)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Pill.fill(t.chip))
    }

    private func accept() {
        isAccepting = true
        Task {
            await session.acceptInviteAndOpen(invite)
            isAccepting = false
        }
    }
}

#Preview("Einladung annehmen", traits: .fixedLayout(width: 390, height: 844)) {
    AcceptInviteView(invite: .init(listId: UUID(), listTitle: "Edeka", inviterPublicId: "Rob"))
        .environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Einladung annehmen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    AcceptInviteView(invite: .init(listId: UUID(), listTitle: "Edeka", inviterPublicId: "Rob"))
        .environmentObject(PreviewMocks.makeAppSessionViewModel()).preferredColorScheme(.dark)
}
