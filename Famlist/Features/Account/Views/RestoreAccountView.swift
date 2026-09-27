/*
 RestoreAccountView.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Screen „Konto wiederherstellen?“ nach der Anmeldung mit einem gelöschten (archivierten) Konto:
   Datum der Löschung, Resttage, was zurückkommt, „Konto wiederherstellen“, „Abmelden“, „Endgültig löschen“.

 🔰 Notes for Beginners:
 - Vorlage: RestoreAccount.dc.html (Zustände default, loading, offline, confirm = RestorePurgeDialog).
   Inhalt links/rechts 24, oben 64, unten 34; Knöpfe unten, solange Platz ist, sonst scrollt der Screen.
 - RootView zeigt diesen Screen, solange AppSessionViewModel.archivedAccount gesetzt ist.
 - Ohne Netz erscheint der rote Hinweis; die Knöpfe lösen dann nichts aus.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct RestoreAccountView: View {
    @EnvironmentObject var session: AppSessionViewModel
    @ObservedObject private var connectivity = ConnectivityMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    let status: AccountArchiveStatus
    /// Vorschau: Zustand „offline“ erzwingen.
    var previewOffline = false
    @State private var phase: Phase = .idle
    @State private var failureText: String?

    enum Phase: Equatable { case idle, restoring, confirming, purging }

    var body: some View {
        let appearance = Appearance(colorScheme)
        let k = SheetTheme(appearance)
        let t = ListAccountTokens(appearance)
        let showsDialog = phase == .confirming || phase == .purging

        ZStack(alignment: .top) {
            EKKScreenBackground(t: EKKTokens(appearance))
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(k: k, t: t)
                        recoveryCard(k: k, t: t)
                            .padding(.top, 20)
                        Spacer(minLength: 24)
                        actions(k: k, t: t)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 64)
                    .padding(.bottom, 34)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .blur(radius: showsDialog ? 3 : 0)
            .accessibilityHidden(showsDialog)

            if showsDialog {
                t.scrimDialog.ignoresSafeArea()
                RestorePurgeDialog(appearance: appearance, isWorking: phase == .purging,
                                   onConfirm: purge, onCancel: { phase = .idle })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var isOffline: Bool { previewOffline || !connectivity.isOnline }

    // MARK: - Kopf

    private func header(k: SheetTheme, t: ListAccountTokens) -> some View {
        let warn: Color = k.isDark ? .hex("#F5B85A") : .hex("#9A5B00")
        let warnSoft: Color = k.isDark ? .rgba(245, 184, 90, 0.14) : .rgba(240, 160, 40, 0.14)
        let days = status.daysLeft()
        return VStack(alignment: .leading, spacing: 0) {
            SVGIcon(RestoreAccountIcon.restore, size: 30, color: t.accentText, lineWidth: 1.8)
                .frame(width: 60, height: 60)
                .background(RR(20).fill(chip(k)))
                .accessibilityHidden(true)

            Text("Konto wiederherstellen?")
                .font(AppFont.outfit(30, 700))
                .tracking(-0.6)                                              // -0.02em × 30
                .foregroundStyle(k.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text(datesText(k: k))
                .font(AppFont.dm(15, 400))
                .foregroundStyle(k.sub)
                .cssLineHeight(21.75, font: AppFont.ui(.dmSans, 15, 400))    // line-height 1.45
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            HStack(spacing: 6) {
                SVGIcon(RestoreAccountIcon.clock, size: 14, color: warn, lineWidth: 2.4)
                Text(days == 1 ? "Noch 1 Tag" : "Noch \(days) Tage")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(warn)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(warnSoft))
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
        }
    }

    private func datesText(k: SheetTheme) -> AttributedString {
        let archived = AppSessionViewModel.archiveDateText(status.archivedAt)
        let purge = AttributedString(AppSessionViewModel.archiveDateText(status.purgeAfter),
                                     attributes: AttributeContainer().font(AppFont.dm(15, 600)).foregroundColor(k.text))
        return AttributedString("Du hast dein Konto am \(archived) gelöscht. Dein Konto wird am ") + purge
            + AttributedString(" endgültig gelöscht.")
    }

    /// Kachel-Hintergrund: Akzent 10 % (hell) bzw. 16 % (dunkel).
    private func chip(_ k: SheetTheme) -> Color { k.a.base.color(k.isDark ? 0.16 : 0.1) }

    // MARK: - Karte „Das bekommst du zurück“

    private func recoveryCard(k: SheetTheme, t: ListAccountTokens) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DAS BEKOMMST DU ZURÜCK")
                .font(AppFont.dm(12, 600))
                .tracking(0.72)                                              // 0.06em × 12
                .foregroundStyle(k.sub)
            row(RestoreAccountIcon.lists, "Deine Listen und Artikel", "inklusive Kategorien und Preisverlauf", k: k, t: t)
            row(RestoreAccountIcon.photos, "Deine Fotos", "Profilbild, Produktfotos und Kassenzettel", k: k, t: t)
            row(RestoreAccountIcon.members, "Deine geteilten Listen", "samt allen Mitgliedern", k: k, t: t)
            row(RestoreAccountIcon.enter, "Listen anderer", "sofern dich niemand zwischenzeitlich entfernt hat", k: k, t: t)
        }
        .padding(.vertical, 15)                                              // 14 + 1 Rahmen
        .padding(.horizontal, 17)                                            // 16 + 1 Rahmen
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    }

    private func row(_ icon: [SVGElement], _ title: String, _ detail: String, k: SheetTheme, t: ListAccountTokens) -> some View {
        HStack(spacing: 12) {
            SVGIcon(icon, size: 19, color: t.accentText, lineWidth: 1.9)
                .frame(width: 36, height: 36)
                .background(RR(12).fill(chip(k)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.text)
                Text(detail)
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(k.sub)
                    .cssLineHeight(17.55, font: AppFont.ui(.dmSans, 13, 400))  // line-height 1.35
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Knöpfe

    private func actions(k: SheetTheme, t: ListAccountTokens) -> some View {
        let busy = phase == .restoring
        return VStack(spacing: 10) {
            if isOffline || failureText != nil {
                notice(k: k, t: t)
            }
            if !isOffline, let email = session.currentUserEmail {
                Text("Angemeldet als \(email)")
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(k.sub)
                    .frame(maxWidth: .infinity)
            }
            Button(action: restore) {
                HStack(spacing: 8) {
                    if busy { ProgressView().controlSize(.small).tint(.white).frame(width: 18, height: 18) }
                    Text(busy ? "Wird wiederhergestellt …" : "Konto wiederherstellen")
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(GlassPillBackground(style: .accent, appearance: k.appearance, accent: k.a, height: 56))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityHint(busy ? "Wird wiederhergestellt" : "")

            HStack(spacing: 10) {
                secondaryButton("Abmelden", color: k.text, k: k) { session.signOut() }
                secondaryButton("Endgültig löschen", color: t.danger, k: k) {
                    guard !isOffline else { return }
                    failureText = nil
                    phase = .confirming
                }
            }
            .opacity(busy ? 0.45 : 1)
            .disabled(busy)
        }
    }

    private func secondaryButton(_ title: String, color: Color, k: SheetTheme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.dm(15, 600))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 50,
                                                glowHeightOverride: 5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Roter Hinweis: offline (Board-Text) oder ein fehlgeschlagener Versuch.
    private func notice(k: SheetTheme, t: ListAccountTokens) -> some View {
        HStack(spacing: 10) {
            SVGIcon(isOffline ? RestoreAccountIcon.offline : ListAccountIcon.warning, size: 20, color: t.danger, lineWidth: 1.9)
            Text(isOffline ? "Zum Wiederherstellen brauchst du eine Internetverbindung." : (failureText ?? ""))
                .font(AppFont.dm(14, 500))
                .foregroundStyle(t.danger)
                .cssLineHeight(19.6, font: AppFont.ui(.dmSans, 14, 500))     // line-height 1.4
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RR(16).fill(t.dangerSoft))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Aktionen

    private func restore() {
        guard !isOffline, phase == .idle else { return }
        failureText = nil
        phase = .restoring
        Task {
            if !(await session.restoreArchivedAccount()) {
                phase = .idle
                if !isOffline { failureText = "Das hat nicht geklappt. Bitte versuche es erneut." }
            }
        }
    }

    private func purge() {
        guard phase == .confirming else { return }
        phase = .purging
        Task {
            if !(await session.purgeArchivedAccount()) {
                phase = .idle
                if !isOffline { failureText = "Das endgültige Löschen hat nicht geklappt. Bitte versuche es erneut." }
            }
        }
    }
}

private extension AccountArchiveStatus {
    /// Beispiel wie im Board: gelöscht heute, endgültig in 60 Tagen.
    static var preview: AccountArchiveStatus {
        AccountArchiveStatus(archivedAt: Date(), purgeAfter: Date().addingTimeInterval(60 * 86_400))
    }
}

#Preview("Konto wiederherstellen", traits: .fixedLayout(width: 390, height: 844)) {
    RestoreAccountView(status: .preview).environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Konto wiederherstellen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    RestoreAccountView(status: .preview).environmentObject(PreviewMocks.makeAppSessionViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Konto wiederherstellen – offline", traits: .fixedLayout(width: 390, height: 844)) {
    RestoreAccountView(status: .preview, previewOffline: true).environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Konto wiederherstellen – offline, Dark", traits: .fixedLayout(width: 390, height: 844)) {
    RestoreAccountView(status: .preview, previewOffline: true).environmentObject(PreviewMocks.makeAppSessionViewModel())
        .preferredColorScheme(.dark)
}
