/*
 SignInView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Screen „Anmelden“: Hero (Famlist), E-Mail-Feld, „Weiter mit E-Mail“ (Anmeldelink), „oder“,
   „Mit Apple anmelden“, Rechtstext.

 🔰 Notes for Beginners:
 - Vorlage: SignInScreen in design-handoff/MyListUI/Screens/OnboardingScreens.swift (SignIn.dc.html).
 - Nach „Weiter mit E-Mail“ erscheint ein Toast „Anmeldelink gesendet“ (Zwischenzustand nicht gestaltet,
   Roberts Entscheidung F2). Der Link öffnet die App über famlist://login-callback.
 - Mit Tastatur rutscht der Inhalt nur so weit nach oben, dass der Knopf sichtbar bleibt.
 - Nur DEBUG im Simulator: langer Druck auf die Korb-Kachel zeigt die Testkonten (Passwort-Anmeldung).
 - Nutzungsbedingungen / Datenschutzerklärung sind (noch) keine Links: Es gibt keine URLs dafür.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5). Ersetzt AuthView.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var keyboard = KeyboardObserver()
    @State private var email = ""
    @State private var toast: String?
    @State private var toastIsError = false
    @State private var apple = AppleSignInCoordinator()
    #if DEBUG && targetEnvironment(simulator)
    @State private var showTestAccounts = false
    #endif

    /// Unterkante des Buttons „Weiter mit E-Mail“ im Design (top 432 + Label 20 + 12 + Feld 54 + 12 + CTA 56).
    private let ctaBottom: CGFloat = 432 + 20 + 12 + 54 + 12 + 56

    var body: some View {
        let appearance = Appearance(colorScheme)
        GeometryReader { geo in
            let screenHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let lift = keyboard.height > 0 ? max(0, ctaBottom - (screenHeight - keyboard.height - 16)) : 0
            content(appearance)
                .offset(y: -lift)
                .animation(.easeOut(duration: 0.25), value: keyboard.height)
                .overlay(alignment: .bottom) { toastView(appearance, keyboardLift: keyboard.height) }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: session.errorMessage) { _, message in
            if let message { show(message, isError: true) }
        }
        #if DEBUG && targetEnvironment(simulator)
        .confirmationDialog("Testkonten (nur Simulator)", isPresented: $showTestAccounts, titleVisibility: .visible) {
            ForEach(SimulatorAuthHelper.TestAccount.allCases, id: \.self) { account in
                Button(account.description) {
                    let c = SimulatorAuthHelper.getCredentials(for: account)
                    session.signInWithEmailPassword(email: c.email, password: c.password)
                }
            }
        }
        #endif
    }

    private func content(_ appearance: Appearance) -> some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        let subtitleFont = AppFont.ui(.dmSans, 17, 400)
        let legalFont = AppFont.ui(.dmSans, 12, 400)

        return ZStack(alignment: .top) {
            EKKScreenBackground(t: t)

            // Hero
            EKKHero(t: t, height: 400) {
                VStack(alignment: .leading, spacing: 18) {
                    SVGIcon(Icon.basket, size: 40, color: .white, lineWidth: 1.7)
                        .frame(width: 86, height: 86)
                        .background(EKKGlassBadge(shape: RR(28), size: 86))
                        .accessibilityHidden(true)
                        #if DEBUG && targetEnvironment(simulator)
                        .onLongPressGesture { showTestAccounts = true }
                        #endif
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Famlist")
                            .font(AppFont.outfit(40, 700))
                            .tracking(-0.8)                                  // -0.02em × 40
                            .foregroundStyle(Color.white)
                            .accessibilityAddTraits(.isHeader)
                        Text("Gemeinsam einkaufen – eine Liste für die ganze Familie.")
                            .font(AppFont.dm(17, 400))
                            .foregroundStyle(Color.rgba(255, 255, 255, 0.9))
                            .cssLineHeight(23.8, font: subtitleFont)          // line-height 1.4
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            // Formular
            VStack(alignment: .leading, spacing: 12) {
                FieldLabel(text: "E-Mail-Adresse", k: k)
                EKKInputField(k: k, text: $email, placeholder: "name@beispiel.de", height: 54, radius: 27,
                              horizontalPadding: 18, keyboard: .emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.send)
                    .onSubmit(sendLink)
                CTAButton(title: session.isLoading ? "Wird gesendet …" : "Weiter mit E-Mail", k: k,
                          isEnabled: !session.isLoading, action: sendLink)

                // „oder“-Trenner, margin 4 0 → 16 Abstand oben/unten
                HStack(spacing: 12) {
                    Rectangle().fill(t.line).frame(height: 1)
                    Text("oder")
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .fixedSize()
                    Rectangle().fill(t.line).frame(height: 1)
                }
                .padding(.vertical, 4)

                // Mit Apple anmelden: 56, Pille, Rahmen 1 (innen), Icon 18 × 20 + 10 + Text
                Button(action: signInWithApple) {
                    HStack(spacing: 10) {
                        SVGIconShape(elements: EKKIcon.apple)
                            .fill(t.appleText)
                            .frame(width: 18, height: 18)               // viewBox 24 → 18 × 18, mittig in 18 × 20
                            .frame(width: 18, height: 20)
                        Text("Mit Apple anmelden")
                            .font(AppFont.dm(16, 600))
                            .foregroundStyle(t.appleText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(CSSBox(shape: Pill, paint: .color(t.appleBg), border: 1, borderColor: k.fieldBorder))
                    .contentShape(Pill)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 432)

            // Rechtstext
            (Text("Mit dem Fortfahren akzeptierst du die ")
                + Text("Nutzungsbedingungen").font(AppFont.dm(12, 600)).foregroundStyle(k.accentText)
                + Text(" und die ")
                + Text("Datenschutzerklärung").font(AppFont.dm(12, 600)).foregroundStyle(k.accentText)
                + Text("."))
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
                .multilineTextAlignment(.center)
                .cssLineHeight(18, font: legalFont)                        // line-height 1.5
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 36)
                .padding(.bottom, 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func toastView(_ appearance: Appearance, keyboardLift: CGFloat) -> some View {
        if let toast {
            StatusToast(text: toast, isError: toastIsError, appearance: appearance)
                .padding(.horizontal, 20)
                .padding(.bottom, keyboardLift > 0 ? keyboardLift + 12 : 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func sendLink() {
        hideKeyboard()
        Task {
            if await session.sendMagicLink(to: email) {
                show("Anmeldelink gesendet – öffne die E-Mail an \(session.magicLinkSentTo ?? email).", isError: false)
            }
        }
    }

    private func signInWithApple() {
        Task {
            guard let result = await apple.signIn() else { return }
            await session.signInWithApple(idToken: result.idToken, nonce: result.nonce)
        }
    }

    private func show(_ text: String, isError: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = text
            toastIsError = isError
        }
        let shown = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if toast == shown { withAnimation { toast = nil } }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview("Anmelden", traits: .fixedLayout(width: 390, height: 844)) {
    SignInView().environmentObject(PreviewMocks.makeAppSessionViewModel())
}

#Preview("Anmelden – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    SignInView().environmentObject(PreviewMocks.makeAppSessionViewModel()).preferredColorScheme(.dark)
}
