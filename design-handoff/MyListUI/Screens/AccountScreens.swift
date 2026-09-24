//  AccountScreens.swift
//  MyListUI
//
//  Konto: „Profil bearbeiten“, „Einstellungen“, „Konto löschen“ (Dialog über Einstellungen).
//  Tokens und Bausteine (`ListAccountTokens`, `ListAccountBackdrop`, `ListAccountSheet`, `ListAccountToggle` …)
//  liegen in `ListManagementScreens.swift`.

import SwiftUI

// MARK: - Profil bearbeiten

// Quelle: Design/html/EditProfile.dc.html (Dark: EditProfileDark.dc.html)
// Hintergrund: Hybrid (ListScreen) + Standard-Abdunkelung. Sheet 726 hoch, unten bündig.
//   Titelzeile → 18 → [Avatar 88 · 16 · „Dein Profil“ 19/600 / 2 / Hinweis 13 (lh 1.4)]
//   → 22 → Benutzername (fokussiert, „@“) + Hinweis 12 → 14 → Vollständiger Name → 14 → E-Mail (gestrichelt, Schloss)
//   → auto → 20 → CTA „Speichern“ → 34
struct EditProfileScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var initialUsername = ""
    var initialFullName = ""
    var email = "robert.bogner@outlook.com"
    var avatarInitial = "R"
    var onClose: () -> Void = {}
    var onChangePhoto: () -> Void = {}
    var onSave: (_ username: String, _ fullName: String) -> Void = { _, _ in }

    @State private var username: String? = nil
    @State private var fullName: String? = nil

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         initialUsername: String = "",
         initialFullName: String = "",
         email: String = "robert.bogner@outlook.com",
         avatarInitial: String = "R",
         onClose: @escaping () -> Void = {},
         onChangePhoto: @escaping () -> Void = {},
         onSave: @escaping (_ username: String, _ fullName: String) -> Void = { _, _ in }) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.initialUsername = initialUsername
        self.initialFullName = initialFullName
        self.email = email
        self.avatarInitial = avatarInitial
        self.onClose = onClose
        self.onChangePhoto = onChangePhoto
        self.onSave = onSave
    }

    var body: some View {
        let t = ListAccountTokens(appearance, accentHex: accentHex)
        let k = t.k
        let userBinding = Binding<String>(get: { username ?? initialUsername }, set: { username = $0 })
        let nameBinding = Binding<String>(get: { fullName ?? initialFullName }, set: { fullName = $0 })
        let introFont = AppFont.ui(.dmSans, 13, 400)

        return ListAccountBackdrop(scrim: t.scrimSheet) {
            ListScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            ListAccountSheet(k: k, height: 726, title: "Profil bearbeiten", onClose: onClose) {
                HStack(spacing: 16) {
                    ListAccountAvatar(t: t, initial: avatarInitial, size: 88, fontSize: 34)
                        .overlay(alignment: .bottomTrailing) {
                            // right −2, bottom −2, 34 × 34, Rahmen 3 (sheetBorder), Hintergrund close
                            Button(action: onChangePhoto) {
                                SVGIcon(ListAccountIcon.camera, size: 16, color: t.accentText, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                                    .background(CSSBox(shape: Circle(), paint: .color(k.close), border: 3,
                                                       borderColor: k.sheetTopBorder))
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 2, y: 2)
                            .accessibilityLabel("Foto ändern")
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dein Profil")
                            .font(AppFont.outfit(19, 600))
                            .foregroundStyle(k.text)
                        Text("So sehen dich andere Mitglieder deiner Listen.")
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(k.sub)
                            .cssLineHeight(18.2, font: introFont)        // line-height 1.4
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 18)

                // Benutzername (fokussiert)
                VStack(alignment: .leading, spacing: 6) {
                    ListAccountFieldGroup(label: "Benutzername", t: t) {
                        ListAccountFocusedField(t: t, text: userBinding, placeholder: "benutzername",
                                                a11yLabel: "Benutzername") {
                            Text("@")
                                .font(AppFont.dm(16, 400))
                                .foregroundStyle(k.sub)
                        }
                    }
                    Text("Pflichtfeld · Buchstaben, Zahlen und _")
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                        .padding(.leading, 4)
                }
                .padding(.top, 22)

                // Vollständiger Name: 52, Radius 16, Rahmen 1, field, Textfarbe sub
                ListAccountFieldGroup(label: "Vollständiger Name (optional)", t: t) {
                    TextField("", text: nameBinding, prompt: Text("Vor- und Nachname").foregroundStyle(t.placeholderOnSub))
                        .font(AppFont.dm(16, 400))
                        .foregroundStyle(k.sub)
                        .tint(k.accent)
                        .accessibilityLabel("Vollständiger Name")
                        .padding(.horizontal, 17)                        // 1 Rahmen + 16 Padding
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                }
                .padding(.top, 14)

                // E-Mail: nicht änderbar – gestrichelter Rahmen 1 (fieldBorder), kein Hintergrund, Schloss 18
                ListAccountFieldGroup(label: "E-Mail-Adresse", t: t) {
                    HStack(spacing: 10) {
                        Text(email)
                            .font(AppFont.dm(16, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SVGIcon(ListAccountIcon.lock, size: 18, color: k.sub, lineWidth: 2)
                            .accessibilityLabel("Nicht änderbar")
                    }
                    .padding(.horizontal, 17)
                    .frame(height: 52)
                    .background(CSSBox(shape: RR(16), border: 1, borderColor: k.fieldBorder, dash: [3, 3]))
                    .accessibilityElement(children: .combine)
                }
                .padding(.top, 14)

                Spacer(minLength: 0)                                     // margin-top: auto
                CTAButton(title: "Speichern", k: k,
                          action: { onSave(userBinding.wrappedValue, nameBinding.wrappedValue) })
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Einstellungen

/// Auswahl im Segment „Erscheinungsbild“.
enum ListAccountAppearanceChoice: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Hell"
    case dark = "Dunkel"
    var id: String { rawValue }
}

// Quelle: Design/html/Settings.dc.html (Dark: SettingsDark.dc.html)
// Hintergrund: Hybrid (ListScreen) + Standard-Abdunkelung. Sheet 790 hoch, unten bündig.
//   Titelzeile → 18 → Profilkarte (padding 14, Radius 22) → 22 → „Erscheinungsbild“ → 10 → Segment
//   → 22 → „Benachrichtigungen“ → 10 → Gruppe (2 Schalter) → 22 → „Konto“ → 10 → Gruppe (Abmelden / Konto löschen)
struct SettingsScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var displayName = "Rob"
    var email = "robert.bogner@outlook.com"
    var avatarInitial = "R"
    var initialAppearanceChoice: ListAccountAppearanceChoice = .system
    var initialNotifySharedChanges = true
    var initialNotifyInvites = true
    var onClose: () -> Void = {}
    var onEditProfile: () -> Void = {}
    var onAppearanceChange: (ListAccountAppearanceChoice) -> Void = { _ in }
    var onSignOut: () -> Void = {}
    var onDeleteAccount: () -> Void = {}

    @State private var choice: ListAccountAppearanceChoice? = nil
    @State private var notifyShared: Bool? = nil
    @State private var notifyInvites: Bool? = nil

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         displayName: String = "Rob",
         email: String = "robert.bogner@outlook.com",
         avatarInitial: String = "R",
         initialAppearanceChoice: ListAccountAppearanceChoice = .system,
         initialNotifySharedChanges: Bool = true,
         initialNotifyInvites: Bool = true,
         onClose: @escaping () -> Void = {},
         onEditProfile: @escaping () -> Void = {},
         onAppearanceChange: @escaping (ListAccountAppearanceChoice) -> Void = { _ in },
         onSignOut: @escaping () -> Void = {},
         onDeleteAccount: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.displayName = displayName
        self.email = email
        self.avatarInitial = avatarInitial
        self.initialAppearanceChoice = initialAppearanceChoice
        self.initialNotifySharedChanges = initialNotifySharedChanges
        self.initialNotifyInvites = initialNotifyInvites
        self.onClose = onClose
        self.onEditProfile = onEditProfile
        self.onAppearanceChange = onAppearanceChange
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
    }

    var body: some View {
        let t = ListAccountTokens(appearance, accentHex: accentHex)
        let k = t.k
        let current = choice ?? initialAppearanceChoice
        let sharedBinding = Binding<Bool>(get: { notifyShared ?? initialNotifySharedChanges }, set: { notifyShared = $0 })
        let invitesBinding = Binding<Bool>(get: { notifyInvites ?? initialNotifyInvites }, set: { notifyInvites = $0 })

        return ListAccountBackdrop(scrim: t.scrimSheet) {
            ListScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            ListAccountSheet(k: k, height: 790, title: "Einstellungen", onClose: onClose) {
                // Profilkarte: padding 14 + Rahmen 1 (border-box), Radius 22, gap 14
                Button(action: onEditProfile) {
                    HStack(spacing: 14) {
                        ListAccountAvatar(t: t, initial: avatarInitial, size: 52, fontSize: 21)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(AppFont.outfit(17, 600))
                                .foregroundStyle(k.text)
                                .lineLimit(1)
                            Text(email)
                                .font(AppFont.dm(13, 400))
                                .foregroundStyle(k.sub)
                                .lineLimit(1)
                                .truncationMode(.tail)
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
                .padding(.top, 18)

                ListAccountSectionLabel(text: "Erscheinungsbild", t: t)
                    .padding(.top, 22)

                // Segment: padding 4, Radius 16, 3 gleich breite Spalten, gap 4; Knopf 40 hoch, Radius 12
                HStack(spacing: 4) {
                    ForEach(ListAccountAppearanceChoice.allCases) { c in
                        let isOn = c == current
                        Button(action: {
                            choice = c
                            onAppearanceChange(c)
                        }) {
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
                .padding(.top, 10)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Erscheinungsbild")

                ListAccountSectionLabel(text: "Benachrichtigungen", t: t)
                    .padding(.top, 22)

                ListAccountSettingsGroup(t: t) {
                    ListAccountSettingsRow(t: t, title: "Änderungen an geteilten Listen", titleColor: k.text,
                                subtitle: "Wenn jemand Artikel hinzufügt oder abhakt", hasTopLine: false) {
                        ListAccountToggle(t: t, isOn: sharedBinding, label: "Änderungen an geteilten Listen")
                    }
                    ListAccountSettingsRow(t: t, title: "Einladungen", titleColor: k.text,
                                subtitle: "Wenn dich jemand zu einer Liste einlädt", hasTopLine: true) {
                        ListAccountToggle(t: t, isOn: invitesBinding, label: "Einladungen")
                    }
                }
                .padding(.top, 10)

                ListAccountSectionLabel(text: "Konto", t: t)
                    .padding(.top, 22)

                ListAccountSettingsGroup(t: t) {
                    Button(action: onSignOut) {
                        ListAccountSettingsRow(t: t, title: "Abmelden", titleColor: t.accentText, subtitle: nil, hasTopLine: false) {
                            EmptyView()
                        }
                    }
                    .buttonStyle(.plain)
                    Button(action: onDeleteAccount) {
                        ListAccountSettingsRow(t: t, title: "Konto löschen", titleColor: t.danger,
                                    subtitle: "Alle deine Daten werden entfernt", hasTopLine: true) {
                            EmptyView()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }
        }
    }
}

/// Gruppe: Radius 20, card, Rahmen 1 cardBorder, overflow hidden, kein Schatten.
private struct ListAccountSettingsGroup<Content: View>: View {
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
private struct ListAccountSettingsRow<Trailing: View>: View {
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
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(t.k.sub)
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

// MARK: - Konto löschen

// Quelle: Design/html/DeleteAccount.dc.html (Dark: DeleteAccountDark.dc.html)
// Hintergrund: Settings (dc-import) + eigene Abdunkelung (.4 / .55).
// Dialog: links/rechts 24, oben 250, padding 24 20 18 20, Radius 28, Rahmen 1, zentriert, gap 10:
//   Warn-Kreis 56 → (4+10) Titel Outfit 21/600 → 10 → Text 14 (lh 1.5) → (8+10) Löschen 52 → 10 → Abbrechen 48
struct DeleteAccountScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onConfirm: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        let t = ListAccountTokens(appearance, accentHex: accentHex)
        let k = t.k
        let bodyFont = AppFont.ui(.dmSans, 14, 400)

        return ListAccountBackdrop(scrim: t.scrimDialog, alignment: .top) {
            SettingsScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            VStack(spacing: 10) {
                SVGIcon(ListAccountIcon.warning, size: 26, color: t.danger, lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(t.dangerSoft))
                    .accessibilityHidden(true)

                Text("Konto löschen?")
                    .font(AppFont.outfit(21, 600))
                    .foregroundStyle(k.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                Text("Deine eigenen Listen, Artikel und Fotos werden dauerhaft gelöscht. Aus geteilten Listen wirst du entfernt. Das lässt sich nicht rückgängig machen.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(k.sub)
                    .multilineTextAlignment(.center)
                    .cssLineHeight(21, font: bodyFont)             // line-height 1.5
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onConfirm) {
                    Text("Konto endgültig löschen")
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Pill.fill(t.danger))
                        .contentShape(Pill)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Button(action: onCancel) {
                    Text("Abbrechen")
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(t.accentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Pill)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 25)                                   // 24 + 1 Rahmen
            .padding(.horizontal, 21)                            // 20 + 1 Rahmen
            .padding(.bottom, 19)                                // 18 + 1 Rahmen
            .frame(maxWidth: .infinity)
            .background(CSSBox(shape: RR(28), paint: .color(t.menu), border: 1, borderColor: t.menuBorder,
                               shadows: t.menuShadow))
            .padding(.horizontal, 24)
            .padding(.top, 250)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}
