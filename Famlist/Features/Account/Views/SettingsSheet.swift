/*
 SettingsSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Einstellungen“ (Höhe 790): Profilkarte (einziger Weg zu „Profil bearbeiten“),
   Erscheinungsbild System/Hell/Dunkel, Benachrichtigungen, Abmelden, Konto löschen.

 🔰 Notes for Beginners:
 - Vorlage: SettingsScreen in design-handoff/MyListUI/Screens/AccountScreens.swift (Settings.dc.html).
 - Erscheinungsbild gilt app-weit (@AppStorage, RootView setzt preferredColorScheme).
 - Benachrichtigungs-Schalter speichern die Einstellung im Profil; einen Push-Versand gibt es noch nicht
   (siehe design-handoff/PLAN.md, Risiko R5).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var session: AppSessionViewModel
    @AppStorage(ListAccountAppearanceChoice.storageKey) private var appearanceRaw = ListAccountAppearanceChoice.system.rawValue
    @AppStorage(PriceDisplaySetting.storageKey) private var showPrices = PriceDisplaySetting.defaultValue
    let appearance: Appearance
    var onClose: () -> Void = {}
    var onEditProfile: () -> Void = {}
    var onDeleteAccount: () -> Void = {}

    private var choice: ListAccountAppearanceChoice { ListAccountAppearanceChoice(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k
        let profile = session.currentProfile
        let sharedBinding = Binding<Bool>(
            get: { profile?.notifySharedLists ?? true },
            set: { session.updateNotifications(sharedLists: $0, invites: profile?.notifyInvites ?? true) })
        let invitesBinding = Binding<Bool>(
            get: { profile?.notifyInvites ?? true },
            set: { session.updateNotifications(sharedLists: profile?.notifySharedLists ?? true, invites: $0) })

        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            ListAccountSheet(k: k, height: 790, title: "Einstellungen", onClose: onClose) {
                // Scrollt, sobald der Inhalt nicht passt (iPhone SE, große iOS-Schrift). Vorher wurden die Zeilen
                // zusammengeschoben und überlappten sich.
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        settingsContent(profile, t: t, k: k, shared: sharedBinding, invites: invitesBinding)
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .task { if session.avatarImage == nil { await session.loadAvatar() } }
    }

    @ViewBuilder
    private func settingsContent(_ profile: Profile?, t: ListAccountTokens, k: SheetTheme,
                                 shared sharedBinding: Binding<Bool>, invites invitesBinding: Binding<Bool>) -> some View {
        profileCard(profile, t: t, k: k)
            .padding(.top, 18)

        ListAccountSectionLabel(text: "Erscheinungsbild", t: t)
            .padding(.top, 22)
        appearanceSegment(t: t, k: k)
            .padding(.top, 10)

        ListAccountSectionLabel(text: "Liste", t: t)
            .padding(.top, 22)
        SettingsGroup(t: t) {
            SettingsRow(t: t, title: "Preise anzeigen", titleColor: k.text,
                        subtitle: "Auf Artikelkarten und in der Fortschrittskarte", hasTopLine: false) {
                ListAccountToggle(t: t, isOn: $showPrices, label: "Preise anzeigen")
            }
        }
        .padding(.top, 10)

        ListAccountSectionLabel(text: "Benachrichtigungen", t: t)
            .padding(.top, 22)
        SettingsGroup(t: t) {
            SettingsRow(t: t, title: "Änderungen an geteilten Listen", titleColor: k.text,
                        subtitle: "Wenn jemand Artikel hinzufügt oder abhakt", hasTopLine: false) {
                ListAccountToggle(t: t, isOn: sharedBinding, label: "Änderungen an geteilten Listen")
            }
            SettingsRow(t: t, title: "Einladungen", titleColor: k.text,
                        subtitle: "Wenn dich jemand zu einer Liste einlädt", hasTopLine: true) {
                ListAccountToggle(t: t, isOn: invitesBinding, label: "Einladungen")
            }
        }
        .padding(.top, 10)

        accountSection(t: t)
    }

    /// Konto: Abmelden, Konto löschen.
    @ViewBuilder
    private func accountSection(t: ListAccountTokens) -> some View {
        ListAccountSectionLabel(text: "Konto", t: t)
            .padding(.top, 22)
        SettingsGroup(t: t) {
            Button(action: { session.signOut() }) {
                SettingsRow(t: t, title: "Abmelden", titleColor: t.accentText, subtitle: nil, hasTopLine: false) {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            // Ungesendete Änderungen (z. B. offline): nachfragen statt still verwerfen (Audit 2, Befund S4).
            // Am Knopf verankert: iOS 26 zeigt den Systemdialog als Sprechblase, die auf „Abmelden“ zeigt.
            .confirmationDialog(unsentTitle, isPresented: unsentBinding, titleVisibility: .visible) {
                Button("Trotzdem abmelden", role: .destructive) { session.signOut(discardingUnsentChanges: true) }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Verbinde dich mit dem Internet und warte kurz, dann wird alles gesendet.")
            }
            Button(action: onDeleteAccount) {
                SettingsRow(t: t, title: "Konto löschen", titleColor: t.danger,
                            subtitle: "Alle deine Daten werden entfernt", hasTopLine: true) {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private var unsentTitle: String {
        let count = session.unsentChangesBeforeSignOut ?? 0
        return count == 1
            ? "1 Änderung ist noch nicht gesendet und geht beim Abmelden verloren."
            : "\(count) Änderungen sind noch nicht gesendet und gehen beim Abmelden verloren."
    }

    private var unsentBinding: Binding<Bool> {
        Binding(get: { session.unsentChangesBeforeSignOut != nil },
                set: { if !$0 { session.unsentChangesBeforeSignOut = nil } })
    }

    /// Profilkarte: padding 14 + Rahmen 1 (border-box), Radius 22, gap 14
    private func profileCard(_ profile: Profile?, t: ListAccountTokens, k: SheetTheme) -> some View {
        Button(action: onEditProfile) {
            HStack(spacing: 14) {
                ListAccountAvatar(t: t, initial: profile?.initial ?? "?", size: 52, fontSize: 21, image: session.avatarImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.displayName ?? "Profil")
                        .font(AppFont.outfit(17, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let email = session.currentUserEmail, !email.isEmpty {      // ohne E-Mail keine leere Zeile
                        Text(email)
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Profil")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.accentText)
                    .fixedSize()
                SVGIcon(Icon.chevronRight, size: 18, color: k.sub, lineWidth: 2.2)
            }
            .padding(15)
            .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder,
                               shadows: t.cardShadow))
            .contentShape(RR(22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profil bearbeiten")
    }

    /// Segment: padding 4, Radius 16, 3 gleich breite Spalten, gap 4; Knopf 40 hoch, Radius 12
    private func appearanceSegment(t: ListAccountTokens, k: SheetTheme) -> some View {
        HStack(spacing: 4) {
            ForEach(ListAccountAppearanceChoice.allCases) { c in
                let isOn = c == choice
                Button(action: { appearanceRaw = c.rawValue }) {
                    Text(c.rawValue)
                        .font(AppFont.dm(14, isOn ? 600 : 500))
                        .foregroundStyle(isOn ? t.segOnText : k.sub)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if isOn {
                                CSSBox(shape: RR(12), paint: .color(t.segOn),
                                       shadows: [.drop(0, 1, 3, 0, .rgba(0, 0, 0, 0.12))])
                            }
                        }
                        .contentShape(RR(12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RR(16).fill(t.segBg))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Erscheinungsbild")
    }
}

/// Gruppe: Radius 20, card, Rahmen 1 cardBorder, overflow hidden, kein Schatten.
private struct SettingsGroup<Content: View>: View {
    let t: ListAccountTokens
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(1)                                          // Rahmen
        .clipShape(RR(20))
        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder))
    }
}

/// Zeile: min. 56 (inkl. border-top 1 bei Folgezeilen), padding 8 14, gap 12;
/// Titel 15/500, darunter optional 12 sub (gap 2), rechts optional Schalter.
private struct SettingsRow<Trailing: View>: View {
    let t: ListAccountTokens
    let title: String
    let titleColor: Color
    let subtitle: String?
    let hasTopLine: Bool
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)        // umbrechen statt abschneiden
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(t.k.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(minHeight: hasTopLine ? 55 : 56)
        .padding(.top, hasTopLine ? 1 : 0)
        .overlay(alignment: .top) {
            if hasTopLine {
                Rectangle().fill(t.line).frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview("Einstellungen", traits: .fixedLayout(width: 390, height: 844)) {
    SettingsSheet(appearance: .light).environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Einstellungen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    SettingsSheet(appearance: .dark).environmentObject(PreviewMocks.makeAppSessionViewModel())
}
