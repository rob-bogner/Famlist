//  OnboardingScreens.swift
//  MyListUI
//
//  Einstieg: „Anmelden“, „Profil einrichten“, „Einladung annehmen“.
//  Enthält außerdem die gemeinsamen Bausteine der Gruppe „Einstieg, Kategorien, Kassenzettel“
//  (Präfix `EKK`): Zusatz-Tokens, Hero-Fläche, Bildschirm-Hintergrund, Sheet-Bühne, Icons.
//  Diese werden auch von CategoryScreens.swift und ReceiptScreens.swift benutzt.

import SwiftUI
import UIKit

// MARK: - Zusatz-Tokens (renderVals() der Einstiegs-/Kategorie-/Kassenzettel-Artboards)

/// Tokens, die `SheetTheme` nicht enthält. Alle übrigen Werte (text, sub, field, ring, cta …)
/// sind in diesen Artboards identisch mit `SheetTheme` und werden von dort genommen.
struct EKKTokens {
    let isDark: Bool
    let a: AccentScale

    let card: Paint
    let cardBorder: Color
    let cardShadow: [BoxShadow]
    let line: Color
    let danger: Color
    let tile: Paint
    let appleBg: Color
    let appleText: Color
    let ok: Color
    let chip: Color
    let ringBase: Color
    let warn: Color
    let warnBorder: Color

    init(_ appearance: Appearance, accentHex: String? = nil) {
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        self.a = a
        isDark = appearance == .dark
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            card = .linear(180, [stop(w(0.07), 0), stop(w(0.03), 1)])
            cardBorder = w(0.08)
            cardShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            line = w(0.08)
            danger = .hex("#FF7A7E")
            tile = .linear(150, [stop(a.base.color(0.24), 0), stop(a.base.color(0.06), 1)])
            appleBg = .white
            appleText = .black
            ok = .hex("#4FD1A1")
            chip = a.base.color(0.16)
            ringBase = .hex("#132426")
            warn = .hex("#F2B24C")
            warnBorder = .rgba(242, 178, 76, 0.5)
        } else {
            card = .color(.white)
            cardBorder = .hex("#EDF2F2")
            cardShadow = [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
            line = .hex("#EDF1F2")
            danger = .hex("#C8363B")
            tile = .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)])
            appleBg = .black
            appleText = .white
            ok = .hex("#1F8A5B")
            chip = a.base.color(0.1)
            ringBase = .white
            warn = .hex("#B7791F")
            warnBorder = .rgba(183, 121, 31, 0.45)
        }
    }

    /// `linear-gradient(150deg, light 0%, accent 42%, deep|deeper 100%)`
    var heroBg: Paint {
        .linear(150, [stop(a.light.color(), 0), stop(a.base.color(), 0.42), stop((isDark ? a.deeper : a.deep).color(), 1)])
    }

    /// `linear-gradient(150deg, light, deep)`
    var avatarBg: Paint {
        .linear(150, [stop(a.light.color(), 0), stop(a.deep.color(), 1)])
    }
}

// MARK: - Gemeinsame Bausteine

/// Bildschirm-Hintergrund `bg`: Light #FFFFFF,
/// Dark `radial-gradient(120% 60% at 50% 100%, accent/.1, transparent 60%), #071012`.
struct EKKScreenBackground: View {
    let t: EKKTokens

    var body: some View {
        if t.isDark {
            ZStack {
                Color.hex("#071012")
                CSSRadialGradient(center: UnitPoint(x: 0.5, y: 1), extent: .ellipse(rx: 1.2, ry: 0.6),
                                  stops: [stop(t.a.base.color(0.1), 0), stop(t.a.base.color(0), 0.6)])
            }
        } else {
            Color.white
        }
    }
}

/// Hero-Fläche (volle Breite, untere Radien 40) mit Glanz-Ellipse und zwei Zierringen.
/// Die Ringe sind `div`s ohne box-sizing → Außenmaß 240 + 2 = 242 bzw. 130 + 2 = 132.
struct EKKHero<Content: View>: View {
    let t: EKKTokens
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40, style: .circular)
    }

    var body: some View {
        ZStack {
            t.heroBg.view
            // left −70, top −120, 340 × 260, radial-gradient(closest-side, weiß .42 → 0)
            CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                              stops: [stop(.rgba(255, 255, 255, 0.42), 0), stop(.rgba(255, 255, 255, 0), 1)])
                .clipShape(Ellipse())
                .frame(width: 340, height: 260)
                .offset(x: -70, y: -120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // right −70, top 60, Rahmen 1 rgba(255,255,255,.14)
            Circle()
                .strokeBorder(Color.rgba(255, 255, 255, 0.14), lineWidth: 1)
                .frame(width: 242, height: 242)
                .offset(x: 70, y: 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // right −10, top 120, Rahmen 1 rgba(255,255,255,.12)
            Circle()
                .strokeBorder(Color.rgba(255, 255, 255, 0.12), lineWidth: 1)
                .frame(width: 132, height: 132)
                .offset(x: 10, y: 120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(shape)
    }
}

/// Glas-Kachel im Hero: `linear-gradient(160deg, weiß .4 → .14)`, Rahmen 1 weiß .45, inset 0 1 0 weiß .6.
struct EKKGlassBadge<S: InsettableShape>: View {
    let shape: S
    let size: CGFloat           // Außenmaß inkl. Rahmen (content-box + 2)

    var body: some View {
        CSSBox(shape: shape,
               paint: .linear(160, [stop(.rgba(255, 255, 255, 0.4), 0), stop(.rgba(255, 255, 255, 0.14), 1)]),
               border: 1, borderColor: .rgba(255, 255, 255, 0.45),
               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6))])
            .frame(width: size, height: size)
    }
}

/// Bühne für Sheets mit frei wählbarem Hintergrund-Screen:
/// Hintergrund + `backdrop-filter: blur(3px)` + Abdunkelung `k.scrim`, Sheet unten bündig.
/// (`SheetScreen` legt fest `ListScreen` darunter; „Kategorie bearbeiten“ braucht „Kategorien verwalten“.)
struct EKKSheetStage<Background: View, Sheet: View>: View {
    let k: SheetTheme
    @ViewBuilder let background: () -> Background
    @ViewBuilder let sheet: () -> Sheet

    var body: some View {
        ZStack(alignment: .bottom) {
            (background as () -> Background)()   // eindeutig: nicht View.background(ignoresSafeAreaEdges:)
                .blur(radius: 3, opaque: true)
                .allowsHitTesting(false)
            k.scrim
            sheet()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// Abschnitts-Überschrift: 13/600, letter-spacing .04em, Großbuchstaben, sub, Einzug 4.
struct EKKSectionLabel: View {
    let text: String
    let k: SheetTheme

    var body: some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .tracking(0.52)
            .textCase(.uppercase)
            .foregroundStyle(k.sub)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Text-Button ohne Fläche: Höhe 48, 15/600.
struct EKKTextButton: View {
    let title: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.dm(15, 600))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Einfaches Eingabefeld (Platzhalter = Textfarbe mit 75 % Deckkraft).
/// Rahmen 1 liegt innen (box-sizing: border-box) → Einzug = 1 + padding.
struct EKKInputField: View {
    let k: SheetTheme
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    let radius: CGFloat
    let horizontalPadding: CGFloat
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(k.sub.opacity(0.75)))
            .keyboardType(keyboard)
            .font(AppFont.dm(16, 400))
            .foregroundStyle(k.sub)
            .tint(k.accent)
            .padding(.horizontal, horizontalPadding + 1)
            .frame(height: height)
            .background(CSSBox(shape: RR(radius), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .accessibilityLabel(placeholder)
    }
}

// MARK: - Icons (Pfade exakt aus den Artboards)

enum EKKIcon {
    static let apple: [SVGElement] = [.path("M16.4 12.6c0-2.4 2-3.6 2.1-3.7-1.2-1.7-3-1.9-3.6-2-1.5-.2-3 .9-3.8.9-.8 0-2-.9-3.3-.9-1.7 0-3.3 1-4.1 2.5-1.8 3.1-.5 7.6 1.3 10.1.8 1.2 1.8 2.6 3.1 2.5 1.2 0 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.4-1-2.4-4.2zM14 5.3c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4z")]
    static let camera: [SVGElement] = [.path("M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z"),
                                       .path("M15.5 12.5a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0z")]
    static let map: [SVGElement] = [.path("M3 7l6-3 6 3 6-3v13l-6 3-6-3-6 3zM9 4v13M15 7v13")]
    static let grip: [SVGElement] = [.path("M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01")]
    static let tag: [SVGElement] = [.path("M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8zM8 7.2v1.6")]
    static let bag: [SVGElement] = [.path("M4 9h16l-1.5 10.5a2 2 0 0 1-2 1.5h-9a2 2 0 0 1-2-1.5zM8 9V6a4 4 0 0 1 8 0v3")]
    static let dropSmall: [SVGElement] = [.path("M12 3c3 3 5 6 5 9a5 5 0 0 1-10 0c0-3 2-6 5-9z")]
    static let bowl: [SVGElement] = [.path("M5 10h14v4a7 7 0 0 1-14 0zM9 6c0-1 1-2 1-3M13 6c0-1 1-2 1-3")]
    static let fruit: [SVGElement] = [.path("M7 20c-2-4-2-9 1-12 2-2 6-2 8 0 3 3 3 8 1 12zM12 8V4")]
    static let umbrella: [SVGElement] = [.path("M4 12a8 8 0 0 1 16 0zM12 12v8M9 20h6")]
    static let cup: [SVGElement] = [.path("M6 3h12l-1 18H7zM6 8h12")]
    static let alert: [SVGElement] = [.path("M12 8v5M12 16.5v.3")]
    static let trend: [SVGElement] = [.path("M4 19h16M6 15l4-4 3 3 5-6")]
    static let flash: [SVGElement] = [.path("M13 2 4 14h7l-1 8 9-12h-7z")]
    static let gallery: [SVGElement] = [.path("M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM4 16l4.5-4.5 4 4 3-3L20 17"),
                                        .path("M16 8.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z")]
}

// MARK: - Anmelden
//
// Quelle: Design/html/SignIn.dc.html (Dark: SignInDark.dc.html)
//  Hero 400 hoch (Inhalt unten, Padding 0/28/40, Abstand 18): Kachel 86 → Titel + Untertitel (Abstand 6)
//  Formular: links/rechts 24, top 432, Abstand 12: Label · Feld 54 · CTA 56 · „oder“ (margin 4) · Apple 56
//  Rechtstext: links/rechts 36, unten 40, 12/1.5

struct SignInScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onContinue: (String) -> Void = { _ in }
    var onApple: () -> Void = {}
    var onTerms: () -> Void = {}
    var onPrivacy: () -> Void = {}

    @State private var email = ""

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         onContinue: @escaping (String) -> Void = { _ in },
         onApple: @escaping () -> Void = {},
         onTerms: @escaping () -> Void = {},
         onPrivacy: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.onContinue = onContinue
        self.onApple = onApple
        self.onTerms = onTerms
        self.onPrivacy = onPrivacy
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)
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
                CTAButton(title: "Weiter mit E-Mail", k: k, action: { onContinue(email) })

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
                Button(action: onApple) {
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
}

// MARK: - Profil einrichten
//
// Quelle: Design/html/ProfileSetup.dc.html (Dark: ProfileSetupDark.dc.html)
//  Spalte links/rechts 24, top 70, unten 34:
//  Schritt-Zeile → 22 → Titel Outfit 30/700 → 8 → Text 15/1.45 → 28 → Foto-Kreis 115 →
//  28 → Benutzername (Feld 54, fokussiert) → 14 → Vollständiger Name (Feld 54) → auto → CTA

struct ProfileSetupScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var initialUsername = "rob"
    var usernameAvailable = true
    /// Statischer Cursor wie im Design (2 × 22, Akzent). In der App `false` → echtes Textfeld mit iOS-Cursor.
    var showsDesignCursor = true
    var onPhoto: () -> Void = {}
    var onSubmit: () -> Void = {}

    @State private var username: String? = nil
    @State private var fullName = ""

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         initialUsername: String = "rob",
         usernameAvailable: Bool = true,
         showsDesignCursor: Bool = true,
         onPhoto: @escaping () -> Void = {},
         onSubmit: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.initialUsername = initialUsername
        self.usernameAvailable = usernameAvailable
        self.showsDesignCursor = showsDesignCursor
        self.onPhoto = onPhoto
        self.onSubmit = onSubmit
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)
        let usernameBinding = Binding<String>(get: { username ?? initialUsername }, set: { username = $0 })
        let bodyFont = AppFont.ui(.dmSans, 15, 400)

        return ZStack(alignment: .top) {
            EKKScreenBackground(t: t)

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

                // Foto: 112 + 2 × 1,5 Rahmen (content-box) = 115, gestrichelt
                Button(action: onPhoto) {
                    VStack(spacing: 4) {
                        SVGIcon(EKKIcon.camera, size: 28, color: k.accentText, lineWidth: 1.8)
                        Text("Foto")
                            .font(AppFont.dm(12, 600))
                            .foregroundStyle(k.sub)
                    }
                    .frame(width: 115, height: 115)
                    .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1.5, borderColor: k.dashed,
                                       dash: [4.5, 4.5]))
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .accessibilityLabel("Foto hinzufügen")

                // Benutzername (fokussiert, Verfügbarkeit)
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Benutzername", k: k)
                    HStack(spacing: 2) {
                        Text("@")
                            .font(AppFont.dm(16, 400))
                            .foregroundStyle(k.sub)
                        if showsDesignCursor {
                            Text(usernameBinding.wrappedValue)
                                .font(AppFont.dm(16, 500))
                                .foregroundStyle(k.text)
                            RR(1)
                                .fill(k.accent)
                                .frame(width: 2, height: 22)
                                .accessibilityHidden(true)
                            Spacer(minLength: 0)
                        } else {
                            TextField("", text: usernameBinding)
                                .font(AppFont.dm(16, 500))
                                .foregroundStyle(k.text)
                                .tint(k.accent)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Benutzername")
                        }
                        if usernameAvailable {
                            HStack(spacing: 4) {
                                SVGIcon(Icon.check, size: 16, color: t.ok, lineWidth: 2.6)
                                Text("frei")
                                    .font(AppFont.dm(13, 600))
                                    .foregroundStyle(t.ok)
                            }
                            .fixedSize()
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Benutzername ist frei")
                        }
                    }
                    .padding(.horizontal, 17.5)                              // 1,5 Rahmen + 16 Padding
                    .frame(height: 54)
                    .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                                       shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Vollständiger Name (optional)", k: k)
                    EKKInputField(k: k, text: $fullName, placeholder: "Vor- und Nachname", height: 54, radius: 16,
                                  horizontalPadding: 16)
                        .textContentType(.name)
                }
                .padding(.top, 14)

                Spacer(minLength: 0)

                CTAButton(title: "Los geht’s", k: k, action: onSubmit)
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

// MARK: - Einladung annehmen
//
// Quelle: Design/html/AcceptInvite.dc.html (Dark: AcceptInviteDark.dc.html)
//  Hero 360 (nur Deko). Karte links/rechts 24, top 150, Padding 28/22/22, Radius 30, Abstand 10, zentriert:
//  Avatar 80 (72 + 2 × 4 Rahmen, margin-top −64) · Einladungstext · „Edeka“ · Chips (+2) · Text (+6) · Buttons (+10)

struct AcceptInviteScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var inviterName = "Rob"
    var listName = "Edeka"
    var itemCount = 4
    var memberCount = 1
    var onAccept: () -> Void = {}
    var onDecline: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)
        let bodyFont = AppFont.ui(.dmSans, 14, 400)

        return ZStack(alignment: .top) {
            EKKScreenBackground(t: t)

            EKKHero(t: t, height: 360) { EmptyView() }

            VStack(spacing: 10) {
                // Avatar: Verlauf über die ganze Border-Box, Rahmen 4 in ringBase darüber
                Text(String(inviterName.prefix(1)))
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
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 8) {
                    inviteChip("\(itemCount) Artikel", k: k, t: t)
                    inviteChip(memberCount == 1 ? "1 Mitglied" : "\(memberCount) Mitglieder", k: k, t: t)
                }
                .padding(.top, 2)

                Text("Ihr seht Änderungen sofort – wer etwas hinzufügt oder abhakt, sehen alle Mitglieder.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(k.sub)
                    .multilineTextAlignment(.center)
                    .cssLineHeight(21, font: bodyFont)                       // line-height 1.5
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                VStack(spacing: 8) {
                    CTAButton(title: "Einladung annehmen", k: k, action: onAccept)
                    EKKTextButton(title: "Ablehnen", color: k.sub, action: onDecline)
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
}
