/*
 ProfileSetupView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Screen „Profil anlegen“ (Schritt 2 von 2): Foto, Benutzername mit Live-Prüfung „frei“,
   vollständiger Name (optional), „Los geht’s“.

 🔰 Notes for Beginners:
 - Vorlage: ProfileSetupScreen in design-handoff/MyListUI/Screens/OnboardingScreens.swift (ProfileSetup.dc.html).
 - Erscheint nach der Anmeldung, solange das Profil keinen Benutzernamen hat (AppSessionViewModel.needsProfileSetup).
 - Vorschlag für den Benutzernamen aus der E-Mail-Adresse. „frei“ erscheint nur, wenn die Prüfung
   bestätigt hat; ist der Name vergeben oder ungültig, steht rechts im Feld ein roter Hinweis (eigener Text).
 - Mit Tastatur rutscht der Inhalt so weit hoch, dass das Feld sichtbar bleibt.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5).
 ------------------------------------------------------------------------
 */

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var keyboard = KeyboardObserver()
    @State private var username = ""
    @State private var fullName = ""
    @State private var check: AppSessionViewModel.UsernameCheck = .empty
    @State private var photo: PhotosPickerItem?
    @State private var isSaving = false
    @FocusState private var usernameFocused: Bool
    /// Unterkanten der beiden Eingabefelder im Scroll-Bereich (ohne Tastatur-Verschiebung) und Bildschirmhöhe.
    @State private var usernameBottom: CGFloat = 0
    @State private var nameBottom: CGFloat = 0
    @State private var screenHeight: CGFloat = 0

    var body: some View {
        let appearance = Appearance(colorScheme)
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        let bodyFont = AppFont.ui(.dmSans, 15, 400)

        ZStack(alignment: .top) {
            EKKScreenBackground(t: t)

            // Knopf unten, solange Platz ist; sonst (iPhone SE, große Schrift) scrollt der Screen,
            // statt dass der Knopf das Namensfeld überdeckt.
            GeometryReader { geo in
            ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Schritt-Anzeige
                HStack(spacing: 0) {
                    Text("Schritt 2 von 2")
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(k.sub)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        RR(3).fill(k.accent).frame(width: 28, height: 6)
                        RR(3).fill(k.accent).frame(width: 28, height: 6)
                    }
                    .accessibilityHidden(true)
                }

                Text("Wie sollen dich andere sehen?")
                    .font(AppFont.outfit(30, 700))
                    .tracking(-0.6)                                          // -0.02em × 30
                    .foregroundStyle(k.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .accessibilityAddTraits(.isHeader)

                Text("Dein Name erscheint bei Artikeln, die du hinzufügst oder abhakst.")
                    .font(AppFont.dm(15, 400))
                    .foregroundStyle(k.sub)
                    .cssLineHeight(21.75, font: bodyFont)                    // line-height 1.45
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                photoButton(k: k, t: t)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)

                usernameField(k: k, t: t)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.scrollSpace)).maxY } action: {
                        usernameBottom = $0
                    }
                    .padding(.top, 28)

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Vollständiger Name (optional)", k: k)
                    EKKInputField(k: k, text: $fullName, placeholder: "Vor- und Nachname", height: 54, radius: 16,
                                  horizontalPadding: 16)
                        .textContentType(.name)
                        .submitLabel(.done)
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.scrollSpace)).maxY } action: {
                    nameBottom = $0
                }
                .padding(.top, 14)

                Spacer(minLength: 24)

                CTAButton(title: isSaving ? "Wird gespeichert …" : "Los geht’s", k: k,
                          isEnabled: check == .available && !isSaving, action: submit)
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            .padding(.bottom, 34)
            .frame(minHeight: geo.size.height, alignment: .top)
            }
            .coordinateSpace(name: Self.scrollSpace)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .onAppear { screenHeight = geo.size.height }
            .onChange(of: geo.size.height) { _, height in screenHeight = height }
            }
            .offset(y: -keyboardLift)
            .animation(.easeOut(duration: 0.25), value: keyboard.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            if username.isEmpty { username = session.suggestedUsername }
        }
        .task(id: username) {
            check = .checking
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            check = await session.checkUsername(username)
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    session.uploadAvatar(image)
                }
            }
        }
    }

    nonisolated private static let scrollSpace = "profileSetupScroll"

    /// Verschiebung bei offener Tastatur: wie bisher bis zu 200 pt (844-pt-Geräte unverändert); reicht das nicht
    /// (iPhone SE, große Schrift), so weit, dass das fokussierte Feld 16 pt über der Tastatur liegt.
    private var keyboardLift: CGFloat {
        guard keyboard.height > 0 else { return 0 }
        guard screenHeight > 0 else { return min(keyboard.height, 200) }
        let fieldBottom = usernameFocused ? usernameBottom : nameBottom
        let needed = fieldBottom + 16 - (screenHeight - keyboard.height)
        return max(min(keyboard.height, 200), needed)
    }

    /// Foto: 112 + 2 × 1,5 Rahmen (content-box) = 115, gestrichelt; mit Foto das Bild im Kreis.
    private func photoButton(k: SheetTheme, t: EKKTokens) -> some View {
        // Vor dem Label lesen: Das Label-Closure von PhotosPicker ist nicht an den Main Actor gebunden.
        let avatar = session.avatarImage
        return PhotosPicker(selection: $photo, matching: .images) {
            Group {
                if let image = avatar {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 115, height: 115)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: 4) {
                        SVGIcon(EKKIcon.camera, size: 28, color: k.accentText, lineWidth: 1.8)
                        Text("Foto")
                            .font(AppFont.dm(12, 600))
                            .foregroundStyle(k.sub)
                    }
                    .frame(width: 115, height: 115)
                    .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1.5, borderColor: k.dashed,
                                       dash: [4.5, 4.5]))
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.avatarImage == nil ? "Foto hinzufügen" : "Foto ändern")
    }

    /// Benutzername (fokussiert, Verfügbarkeit)
    private func usernameField(k: SheetTheme, t: EKKTokens) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: "Benutzername", k: k)
            HStack(spacing: 2) {
                Text("@")
                    .font(AppFont.dm(16, 400))
                    .foregroundStyle(k.sub)
                TextField("", text: $username)
                    .font(AppFont.dm(16, 500))
                    .foregroundStyle(k.text)
                    .tint(k.accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($usernameFocused)
                    .submitLabel(.next)
                    .accessibilityLabel("Benutzername")
                status(k: k, t: t)
            }
            .padding(.horizontal, 17.5)                              // 1,5 Rahmen + 16 Padding
            .frame(height: 54)
            .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                               shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
        }
    }

    @ViewBuilder
    private func status(k: SheetTheme, t: EKKTokens) -> some View {
        switch check {
        case .available:
            HStack(spacing: 4) {
                SVGIcon(Icon.check, size: 16, color: t.ok, lineWidth: 2.6)
                Text("frei")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.ok)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Benutzername ist frei")
        case .taken, .invalid, .unknown:
            Text(check == .taken ? "vergeben" : check == .invalid ? "ungültig" : "offline")
                .font(AppFont.dm(13, 600))
                .foregroundStyle(t.danger)
                .fixedSize()
        case .checking:
            ProgressView().controlSize(.small).tint(k.accent)
        case .empty:
            EmptyView()
        }
    }

    private func submit() {
        isSaving = true
        Task {
            let ok = await session.saveProfile(username: username.trimmingCharacters(in: .whitespaces), fullName: fullName)
            isSaving = false
            if !ok { check = await session.checkUsername(username) }
        }
    }
}

#Preview("Profil anlegen", traits: .fixedLayout(width: 390, height: 844)) {
    ProfileSetupView().environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Profil anlegen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ProfileSetupView().environmentObject(PreviewMocks.makeAppSessionViewModel()).preferredColorScheme(.dark)
}
