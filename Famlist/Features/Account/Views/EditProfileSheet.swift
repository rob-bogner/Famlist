/*
 EditProfileSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Profil bearbeiten“ (Höhe 726): Avatar mit Kamera-Knopf, Benutzername (Pflicht, Live-Prüfung),
   vollständiger Name (optional), E-Mail (nicht änderbar), „Speichern“.

 🔰 Notes for Beginners:
 - Vorlage: EditProfileScreen in design-handoff/MyListUI/Screens/AccountScreens.swift (EditProfile.dc.html).
 - Nur über die Profilkarte in den Einstellungen erreichbar (SPEC §3.9).
 - Unter dem Benutzernamen steht der Design-Hinweis; ist der Name vergeben oder ungültig, erscheint
   stattdessen eine rote Meldung (eigener Text, Design zeigt nur den Hinweis).
 - Das Foto wählt der System-Fotopicker (PhotosPicker); hochgeladen wird es sofort.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4). Ersetzt ProfileView.
 ------------------------------------------------------------------------
 */

import SwiftUI
import PhotosUI

struct EditProfileSheet: View {
    @EnvironmentObject var session: AppSessionViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}

    @State private var username = ""
    @State private var fullName = ""
    @State private var check: AppSessionViewModel.UsernameCheck = .empty
    @State private var photo: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k
        let introFont = AppFont.ui(.dmSans, 13, 400)

        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            ListAccountSheet(k: k, height: 726, title: "Profil bearbeiten", onClose: onClose) {
                HStack(spacing: 16) {
                    ListAccountAvatar(t: t, initial: session.currentProfile?.initial ?? "?", size: 88, fontSize: 34,
                                      image: session.avatarImage)
                        .overlay(alignment: .bottomTrailing) {
                            // right −2, bottom −2, 34 × 34, Rahmen 3 (sheetBorder), Hintergrund close
                            PhotosPicker(selection: $photo, matching: .images) {
                                SVGIcon(ListAccountIcon.camera, size: 16, color: t.accentText, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                                    .background(CSSBox(shape: Circle(), paint: .color(k.close), border: 3,
                                                       borderColor: k.sheetTopBorder))
                                    .frame(width: 44, height: 44)     // Trefferfläche 44, Optik 34
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(-5)                              // 44er-Trefferfläche ohne Layout-Versatz
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
                        ListAccountFocusedField(t: t, text: $username, placeholder: "benutzername",
                                                a11yLabel: "Benutzername", submitLabel: .next) {
                            Text("@")
                                .font(AppFont.dm(16, 400))
                                .foregroundStyle(k.sub)
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                    Text(hint.text)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(hint.isError ? t.danger : k.sub)
                        .padding(.leading, 4)
                }
                .padding(.top, 22)

                // Vollständiger Name: 52, Radius 16, Rahmen 1, field, Textfarbe sub
                ListAccountFieldGroup(label: "Vollständiger Name (optional)", t: t) {
                    TextField("", text: $fullName, prompt: Text("Vor- und Nachname").foregroundStyle(t.placeholderOnSub))
                        .font(AppFont.dm(16, 400))
                        .foregroundStyle(k.sub)
                        .tint(k.accent)
                        .submitLabel(.done)
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
                        Text(session.currentUserEmail ?? "–")
                            .font(AppFont.dm(16, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
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
                CTAButton(title: isSaving ? "Wird gespeichert …" : "Speichern", k: k,
                          isEnabled: check == .available && !isSaving, action: save)
                    .padding(.top, 20)
            }
        }
        .onAppear {
            username = session.currentProfile?.username ?? ""
            fullName = session.currentProfile?.fullName ?? ""
        }
        .task(id: username) {
            check = .checking
            try? await Task.sleep(nanoseconds: 350_000_000)          // Tippen abwarten
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

    private var hint: (text: String, isError: Bool) {
        switch check {
        case .invalid: return ("Nur Buchstaben, Zahlen und _ · mindestens 3 Zeichen", true)
        case .taken: return ("@\(username) ist schon vergeben", true)
        case .unknown: return ("Verfügbarkeit gerade nicht prüfbar", true)
        default: return ("Pflichtfeld · Buchstaben, Zahlen und _", false)
        }
    }

    private func save() {
        isSaving = true
        Task {
            let ok = await session.saveProfile(username: username.trimmingCharacters(in: .whitespaces),
                                               fullName: fullName)
            isSaving = false
            if ok { onClose() } else { check = await session.checkUsername(username) }
        }
    }
}

#Preview("Profil bearbeiten", traits: .fixedLayout(width: 390, height: 844)) {
    EditProfileSheet(appearance: .light).environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Profil bearbeiten – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    EditProfileSheet(appearance: .dark).environmentObject(PreviewMocks.makeAppSessionViewModel())
}
