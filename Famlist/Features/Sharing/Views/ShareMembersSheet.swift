/*
 ShareMembersSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Mitglieder & Teilen“ (Höhe 708): Mitgliederliste, „Einladungslink teilen“ (Share Sheet),
   „Link kopieren“ und die eigene öffentliche ID mit Kopier-Knopf.

 🔰 Notes for Beginners:
 - Vorlage: ShareMembersScreen in design-handoff/MyListUI/Screens/ListManagementScreens.swift
   (ShareMembers.dc.html). Werte 1:1, Beispieldaten durch ShareMembersViewModel ersetzt.
 - Ergänzung (nicht im Design): Der Besitzer kann ein Mitglied per Wischen entfernen – das konnte die
   alte Mitglieder-Ansicht auch. Ohne Design dafür gleicher roter Knopf wie in „Artikel verwalten“.
 - Bei vielen Mitgliedern scrollt der Inhalt (Design zeigt ein Mitglied).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4). Ersetzt ShareListView und MembersView.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ShareMembersSheet: View {
    @StateObject private var vm: ShareMembersViewModel
    let appearance: Appearance
    let publicID: String
    var onClose: () -> Void = {}

    @State private var copiedLink = false
    @State private var copiedID = false

    init(viewModel: ShareMembersViewModel, appearance: Appearance, publicID: String, onClose: @escaping () -> Void = {}) {
        _vm = StateObject(wrappedValue: viewModel)
        self.appearance = appearance
        self.publicID = publicID
        self.onClose = onClose
    }

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k

        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            ListAccountSheet(k: k, height: 708, title: "Mitglieder & Teilen", onClose: onClose) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        membersSection(t: t, k: k)
                        inviteSection(t: t, k: k)
                        publicIDSection(t: t, k: k)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = vm.errorMessage {
                StatusToast(text: message, isError: true, appearance: appearance)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation { vm.errorMessage = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.errorMessage)
        .task { await vm.load() }
    }

    // MARK: - Mitglieder

    @ViewBuilder
    private func membersSection(t: ListAccountTokens, k: SheetTheme) -> some View {
        let dashed = k.a.base.color(0.4)                     // ShareMembers: dashed = rgba(accent, .4)
        let hintFont = AppFont.ui(.dmSans, 14, 400)

        ListAccountSectionLabel(text: "Mitglieder · \(vm.members.count)", t: t)
            .padding(.top, 20)

        VStack(spacing: 10) {
            ForEach(vm.members) { m in
                if vm.isOwner && !m.isOwner {
                    SwipeToDeleteRow(labelColor: k.sub, columnHeight: 74, onDelete: { vm.remove(m) }) {
                        memberCard(m, t: t, k: k)
                    }
                } else {
                    memberCard(m, t: t, k: k)
                }
            }
        }
        .padding(.top, 10)

        if vm.members.count <= 1 {
            // Gestrichelter Hinweis: padding 12 14 (+1,5 Rahmen), Radius 18, gap 12.
            // Das SVG (22) wird im Browser per flex-shrink auf ≈ 12,5 pt gestaucht (langer Text) –
            // hier exakt so nachgebildet: Icon 12,5 in einer 22 hohen Box.
            HStack(spacing: 12) {
                SVGIcon(ListAccountIcon.personAdd, size: 12.5, color: t.accentText, lineWidth: 1.8)
                    .frame(width: 12.5, height: 22)
                    .accessibilityHidden(true)
                Text("Noch niemand eingeladen. Teile den Link, um Familie oder Freunde dazuzuholen.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(k.sub)
                    .cssLineHeight(19.6, font: hintFont)       // line-height 1.4
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 13.5)
            .padding(.horizontal, 15.5)
            .background(CSSBox(shape: RR(18), border: 1.5, borderColor: dashed, dash: [4.5, 4.5]))
            .padding(.top, 10)
        }
    }

    /// Karte: padding 13 14 (+1 Rahmen, content-box), Radius 22, gap 14
    private func memberCard(_ m: ShareMember, t: ListAccountTokens, k: SheetTheme) -> some View {
        HStack(spacing: 14) {
            ListAccountAvatar(t: t, initial: m.initial, size: 44, fontSize: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name)
                    .font(AppFont.outfit(17, 600))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(m.role)
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(k.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 15)
        .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder,
                           shadows: t.cardShadow))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Einladen

    @ViewBuilder
    private func inviteSection(t: ListAccountTokens, k: SheetTheme) -> some View {
        ListAccountSectionLabel(text: "Einladen", t: t)
            .padding(.top, 24)

        VStack(spacing: 10) {
            ListAccountIconCTA(k: k, icon: ListAccountIcon.share, title: "Einladungslink teilen",
                               action: { Task { await vm.ensureInviteURL() } }, shareURL: vm.inviteURL)

            // Sekundär: 52 hoch, Radius 26, Rahmen 1, field, accentText 15/600, Icon 18, gap 10
            Button(action: copyLink) {
                HStack(spacing: 10) {
                    SVGIcon(copiedLink ? Icon.check : ListAccountIcon.copy, size: 18, color: t.accentText, lineWidth: 2)
                    Text(copiedLink ? "Link kopiert" : "Link kopieren")
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(t.accentText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                .contentShape(Pill)
            }
            .buttonStyle(.plain)

            Text("Der Link funktioniert nur mit installierter Famlist-App.")
                .font(AppFont.dm(13, 400))
                .foregroundStyle(k.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
    }

    // MARK: - Öffentliche ID

    @ViewBuilder
    private func publicIDSection(t: ListAccountTokens, k: SheetTheme) -> some View {
        let idHintFont = AppFont.ui(.dmSans, 12, 400)

        Rectangle()
            .fill(t.line)
            .frame(height: 1)
            .padding(.top, 22)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Deine öffentliche ID")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(k.sub)
                // font-family: ui-monospace, 'SF Mono' → SF Mono
                Text(publicID)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .textSelection(.enabled)
                Text("Andere können dich damit finden und einladen.")
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .cssLineHeight(16.2, font: idHintFont)     // line-height 1.35
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: copyID) {
                SVGIcon(copiedID ? Icon.check : ListAccountIcon.copy, size: 18, color: t.accentText, lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copiedID ? "ID kopiert" : "ID kopieren")
        }
        .padding(.top, 18)
    }

    // MARK: - Actions

    private func copyLink() {
        guard let url = vm.inviteURL else {
            Task { await vm.ensureInviteURL() }
            return
        }
        UIPasteboard.general.string = url.absoluteString
        UserLog.Data.inviteLinkCopied(listName: vm.list.title)
        flash($copiedLink)
    }

    private func copyID() {
        UIPasteboard.general.string = publicID
        flash($copiedID)
    }

    /// Kurz „kopiert“ mit Haken zeigen (2 s), wie „Kopiert“ im Dock.
    private func flash(_ flag: Binding<Bool>) {
        withAnimation(.easeInOut(duration: 0.2)) { flag.wrappedValue = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { flag.wrappedValue = false }
        }
    }
}

#Preview("Mitglieder & Teilen", traits: .fixedLayout(width: 390, height: 844)) {
    ShareMembersSheet(viewModel: ShareMembersViewModel(
        list: ListModel(id: UUID(), ownerId: UUID(), title: "My List", isDefault: true, createdAt: Date(), updatedAt: Date()),
        me: nil, lists: nil, profiles: nil), appearance: .light, publicID: "test_public_id")
}

#Preview("Mitglieder & Teilen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ShareMembersSheet(viewModel: ShareMembersViewModel(
        list: ListModel(id: UUID(), ownerId: UUID(), title: "My List", isDefault: true, createdAt: Date(), updatedAt: Date()),
        me: nil, lists: nil, profiles: nil), appearance: .dark, publicID: "test_public_id")
}
