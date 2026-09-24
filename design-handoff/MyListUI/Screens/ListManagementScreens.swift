//  ListManagementScreens.swift
//  MyListUI
//
//  Listenverwaltung: „Neue Liste“, „Listen-Optionen“ (Menü über „Meine Listen“), „Mitglieder & Teilen“.
//  Enthält außerdem die gemeinsamen Tokens/Bausteine der Gruppe „Listen & Konto“
//  (Präfix `ListAccount…`), die auch `AccountScreens.swift` benutzt.

import SwiftUI

// MARK: - Tokens (renderVals() der Dateien CreateList/ListOptions/ShareMembers/EditProfile/Settings/DeleteAccount)

/// Zusatz-Tokens, die `SheetTheme` nicht enthält. Werte 1:1 aus `k` im Design.
/// Identische Werte (field, fieldBorder, fieldFocus, ring, ringSoft, close, icon …) kommen aus `SheetTheme`.
struct ListAccountTokens {
    let k: SheetTheme
    var isDark: Bool { k.isDark }

    /// Für Platzhalter (`input::placeholder { color: inherit; opacity: .75 }`)
    let textHex: String
    let subHex: String

    let card: Paint
    let cardBorder: Color
    let cardShadow: [BoxShadow]
    let line: Color
    let accentText: Color
    let danger: Color
    let dangerSoft: Color
    let toggleOn: Paint
    let toggleOff: Color
    let segBg: Color
    let segOn: Color
    let segOnText: Color
    let menu: Color
    let menuBorder: Color
    let menuShadow: [BoxShadow]
    /// `avatarBg: linear-gradient(150deg, light, deep)`
    let avatar: Paint

    init(_ appearance: Appearance, accentHex: String? = nil) {
        let k = SheetTheme(appearance, accentHex: accentHex)
        self.k = k
        let a = k.a
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }
        avatar = .linear(150, [stop(a.light.color(), 0), stop(a.deep.color(), 1)])

        if appearance == .dark {
            textHex = "#EAF5F6"
            subHex = "#93ADB1"
            card = .linear(180, [stop(w(0.07), 0), stop(w(0.03), 1)])
            cardBorder = w(0.08)
            cardShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            line = w(0.08)
            accentText = a.light.color()
            danger = .hex("#FF7A7E")
            dangerSoft = .rgba(255, 122, 126, 0.12)
            toggleOn = .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            toggleOff = w(0.14)
            segBg = w(0.06)
            segOn = w(0.14)
            segOnText = .white
            menu = .rgba(20, 34, 37, 0.97)
            menuBorder = w(0.1)
            menuShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 24, 48, -16, .rgba(0, 0, 0, 0.8))]
        } else {
            textHex = "#0F2528"
            subHex = "#5F7579"
            card = .color(.white)
            cardBorder = .hex("#EDF2F2")
            cardShadow = [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
            line = .hex("#EDF1F2")
            accentText = a.deep.color()
            danger = .hex("#C8363B")
            dangerSoft = .rgba(200, 54, 59, 0.08)
            toggleOn = .linear(180, [stop(a.base.color(), 0), stop(a.deep.color(), 1)])
            toggleOff = .hex("#DCE5E6")
            segBg = .hex("#F1F5F5")
            segOn = .white
            segOnText = .hex("#0F2528")
            menu = .rgba(255, 255, 255, 0.97)
            menuBorder = .rgba(15, 37, 40, 0.08)
            menuShadow = [.drop(0, 24, 48, -16, .rgba(12, 40, 44, 0.35))]
        }
    }

    /// Platzhalterfarbe eines Eingabefelds mit Textfarbe `text` bzw. `sub`, α 0,75.
    var placeholderOnText: Color { .hex(textHex, 0.75) }
    var placeholderOnSub: Color { .hex(subHex, 0.75) }

    // Abdunkelungen – je Artboard unterschiedlich
    /// Standard (Sheets): Light rgba(8,24,27,.42), Dark rgba(0,0,0,.6)
    var scrimSheet: Color { k.scrim }
    /// ListOptions (Menü): Light rgba(8,24,27,.16), Dark rgba(0,0,0,.35)
    var scrimMenu: Color { isDark ? .rgba(0, 0, 0, 0.35) : .rgba(8, 24, 27, 0.16) }
    /// DeleteAccount (Dialog): Light rgba(8,24,27,.4), Dark rgba(0,0,0,.55)
    var scrimDialog: Color { isDark ? .rgba(0, 0, 0, 0.55) : .rgba(8, 24, 27, 0.4) }
}

// MARK: - Icons (Pfade exakt aus dem HTML, soweit nicht im Katalog `Icon`)

enum ListAccountIcon {
    /// ListOptions/ShareMembers „Duplizieren“ / „Link kopieren“ (Pfad-Variante, nicht `Icon.duplicate`)
    static let copy: [SVGElement] = [.path("M10 8h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2zM16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2")]
    /// „Mitglieder & Teilen“
    static let members: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5s5.5 1.5 6.5 4.5M19.5 9a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0zM16 14.6c2.6.2 4.6 1.6 5.5 4.4")]
    /// Person mit Plus (ShareMembers, leerer Zustand)
    static let personAdd: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5 1.6 0 3 .4 4.2 1.2M18 14v6M15 17h6")]
    /// Teilen (Pfeil aus Box)
    static let share: [SVGElement] = [.path("M12 3v12M8 7l4-4 4 4M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7")]
    /// Kamera (EditProfile, Kreis als Pfad)
    static let camera: [SVGElement] = [.path("M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z"),
                                       .path("M15.5 12.5a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0z")]
    /// Schloss (E-Mail nicht änderbar)
    static let lock: [SVGElement] = [.path("M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3")]
    /// Warnung (Konto löschen)
    static let warning: [SVGElement] = [.path("M12 4 2.5 20h19L12 4zM12 10v4.5M12 17.3v.2")]
}

// MARK: - Gemeinsame Bausteine

/// Hintergrund-Artboard (per `dc-import`) + `backdrop-filter: blur(3px)` + Abdunkelung, darüber der Inhalt.
/// Ersetzt `SheetScreen`, weil der Hintergrund hier je nach Artboard wechselt (Hybrid, MyLists, Settings)
/// und die Abdunkelung je Artboard verschieden ist.
struct ListAccountBackdrop<Background: View, Content: View>: View {
    let scrim: Color
    var alignment: Alignment = .bottom
    @ViewBuilder let background: () -> Background
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: alignment) {
            (background as () -> Background)()   // eindeutig: nicht View.background(ignoresSafeAreaEdges:)
                .blur(radius: 3, opaque: true)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            scrim
                .allowsHitTesting(false)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// Sheet mit `display: flex; flex-direction: column; padding: 10px 20px 34px 20px`:
/// Griff → 12 → Titelzeile, danach der Inhalt (oben ausgerichtet).
struct ListAccountSheet<Content: View>: View {
    let k: SheetTheme
    let height: CGFloat
    let title: String
    var onClose: () -> Void = {}
    @ViewBuilder let content: () -> Content

    var body: some View {
        SheetSurface(k: k, height: height) {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: title, k: k, onClose: onClose)
                content()
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Abschnittsüberschrift: 13/600, letter-spacing .04em, Großbuchstaben, sub, padding 0 4.
struct ListAccountSectionLabel: View {
    let text: String
    let t: ListAccountTokens

    var body: some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .tracking(0.52)                          // 0.04em × 13
            .textCase(.uppercase)
            .foregroundStyle(t.k.sub)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// iOS-Schalter wie im Design: 51 × 31, Radius 16, Knopf 25 (3 pt Rand), Schatten 0 2 4 rgba(0,0,0,.2).
struct ListAccountToggle: View {
    let t: ListAccountTokens
    @Binding var isOn: Bool
    var label: String = ""

    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                if isOn {
                    CSSBox(shape: Pill, paint: t.toggleOn)
                } else {
                    Pill.fill(t.toggleOff)
                }
                Color.clear
                    .frame(width: 25, height: 25)
                    .background(CSSBox(shape: Circle(), paint: .color(.white),
                                       shadows: [.drop(0, 2, 4, 0, .rgba(0, 0, 0, 0.2))]))
                    .padding(3)
            }
            .frame(width: 51, height: 31)
            .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Ein" : "Aus")
        .accessibilityAddTraits(.isToggle)
    }
}

/// Runder Avatar mit Initiale: Verlauf 150° light → deep, inset 0 1px 0 rgba(255,255,255,.45), Outfit 600 weiß.
struct ListAccountAvatar: View {
    let t: ListAccountTokens
    let initial: String
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Text(initial)
            .font(AppFont.outfit(fontSize, 600))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(CSSBox(shape: Circle(), paint: t.avatar,
                               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45))]))
    }
}

/// Feld-Beschriftung (13/600, sub, padding-left 4) + 6 + Feld.
struct ListAccountFieldGroup<Field: View>: View {
    let label: String
    let t: ListAccountTokens
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(t.k.sub)
                .padding(.leading, 4)
            field()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Fokussiertes Textfeld: 52 hoch, Radius 16, Rahmen 1,5 ring, 4-pt-Ring ringSoft, padding 0 16, gap 2.
/// `leading` ist das Element vor dem Eingabefeld (Design-Cursor bzw. „@“).
struct ListAccountFocusedField<Leading: View>: View {
    let t: ListAccountTokens
    @Binding var text: String
    let placeholder: String
    let a11yLabel: String
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        let k = t.k
        HStack(spacing: 2) {
            leading()
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(t.placeholderOnText))
                .font(AppFont.dm(16, 400))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .accessibilityLabel(a11yLabel)
        }
        .padding(.horizontal, 17.5)                          // 1,5 Rahmen + 16 Padding
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                           shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
    }
}

/// Statischer Design-Cursor: 2 × 22, Radius 1, Akzent.
struct ListAccountDesignCaret: View {
    let t: ListAccountTokens

    var body: some View {
        RR(1)
            .fill(t.k.accent)
            .frame(width: 2, height: 22)
            .accessibilityHidden(true)
    }
}

// MARK: - Neue Liste

// Quelle: Design/html/CreateList.dc.html (Dark: CreateListDark.dc.html)
// Hintergrund: MyLists (dc-import) + Standard-Abdunkelung. Sheet 392 hoch, unten bündig.
//   Titelzeile → 20 → „Name der Liste“ / 6 / fokussiertes Feld 52 → 16 → Favoriten-Zeile → auto → 20 → CTA 56 → 34
struct CreateListScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var initialName = ""
    var initialFavorite = false
    /// Statischer Cursor wie im Design. In der App `false` – dann zeichnet iOS den Cursor (.tint).
    var showsDesignCursor = true
    var onClose: () -> Void = {}
    var onCreate: (_ name: String, _ isFavorite: Bool) -> Void = { _, _ in }

    @State private var name: String? = nil
    @State private var isFavorite: Bool? = nil

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         initialName: String = "",
         initialFavorite: Bool = false,
         showsDesignCursor: Bool = true,
         onClose: @escaping () -> Void = {},
         onCreate: @escaping (_ name: String, _ isFavorite: Bool) -> Void = { _, _ in }) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.initialName = initialName
        self.initialFavorite = initialFavorite
        self.showsDesignCursor = showsDesignCursor
        self.onClose = onClose
        self.onCreate = onCreate
    }

    var body: some View {
        let t = ListAccountTokens(appearance, accentHex: accentHex)
        let k = t.k
        let nameBinding = Binding<String>(get: { name ?? initialName }, set: { name = $0 })
        let favBinding = Binding<Bool>(get: { isFavorite ?? initialFavorite }, set: { isFavorite = $0 })

        return ListAccountBackdrop(scrim: t.scrimSheet) {
            MyListsScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            ListAccountSheet(k: k, height: 392, title: "Neue Liste", onClose: onClose) {
                ListAccountFieldGroup(label: "Name der Liste", t: t) {
                    ListAccountFocusedField(t: t, text: nameBinding, placeholder: "z. B. Edeka oder Wochenmarkt",
                                            a11yLabel: "Name der Liste") {
                        if showsDesignCursor { ListAccountDesignCaret(t: t) }
                    }
                }
                .padding(.top, 20)

                // Favoriten-Zeile: padding 12 14 (+1 Rahmen, content-box), Radius 18, gap 12
                HStack(spacing: 12) {
                    SVGFilledIcon(Icon.star, size: 20, color: .hex("#F5B521"), lineWidth: 1.5)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Als Favorit")
                            .font(AppFont.dm(15, 500))
                            .foregroundStyle(k.text)
                        Text("Öffnet sich beim App-Start")
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ListAccountToggle(t: t, isOn: favBinding, label: "Als Favorit")
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 15)
                .background(CSSBox(shape: RR(18), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                .padding(.top, 16)

                Spacer(minLength: 0)                               // margin-top: auto
                CTAButton(title: "Liste erstellen", k: k, action: { onCreate(nameBinding.wrappedValue, favBinding.wrappedValue) })
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Listen-Optionen

// Quelle: Design/html/ListOptions.dc.html (Dark: ListOptionsDark.dc.html)
// Hintergrund: MyLists (dc-import) + eigene, leichtere Abdunkelung (.16 / .35).
// Menü: rechts 20, oben 262, Breite 262, padding 6, Radius 24, Rahmen 1.
//   Kopf „My List“ 12/600 (padding 10 12 6 12) → 4 Einträge à 48 → Trennlinie (margin 4 10) → „Liste löschen“ (min. 56)
struct ListOptionsScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var listName = "My List"
    var isFavorite = true
    var onRename: () -> Void = {}
    var onDuplicate: () -> Void = {}
    var onToggleFavorite: () -> Void = {}
    var onMembers: () -> Void = {}
    var onDelete: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        let t = ListAccountTokens(appearance, accentHex: accentHex)
        let k = t.k

        return ListAccountBackdrop(scrim: t.scrimMenu, alignment: .topTrailing) {
            MyListsScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            ZStack(alignment: .topTrailing) {
                // Tippen außerhalb schließt das Menü
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(listName)
                        .font(AppFont.dm(12, 600))
                        .tracking(0.72)                          // 0.06em × 12
                        .textCase(.uppercase)
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                        .padding(.top, 10)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .accessibilityAddTraits(.isHeader)

                    ListAccountMenuItem(t: t, icon: Icon.pencil, title: "Umbenennen", action: onRename)
                    ListAccountMenuItem(t: t, icon: ListAccountIcon.copy, title: "Duplizieren", action: onDuplicate)
                    ListAccountMenuItem(t: t, icon: Icon.star,
                                        title: isFavorite ? "Favorit entfernen" : "Als Favorit markieren",
                                        action: onToggleFavorite)
                    ListAccountMenuItem(t: t, icon: ListAccountIcon.members, title: "Mitglieder & Teilen", action: onMembers)

                    Rectangle()
                        .fill(t.line)
                        .frame(height: 1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)

                    Button(action: onDelete) {
                        HStack(spacing: 12) {
                            SVGIcon(Icon.trash, size: 20, color: t.danger, lineWidth: 1.9)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Liste löschen")
                                    .font(AppFont.dm(15, 600))
                                    .foregroundStyle(t.danger)
                                Text("Bei geteilten Listen: „Liste verlassen“")
                                    .font(AppFont.dm(12, 400))
                                    .foregroundStyle(k.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(RR(16).fill(t.dangerSoft))
                        .contentShape(RR(16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(7)                                          // 6 Padding + 1 Rahmen
                .frame(width: 262)
                .background(CSSBox(shape: RR(24), paint: .color(t.menu), border: 1, borderColor: t.menuBorder,
                                   shadows: t.menuShadow))
                .padding(.top, 262)
                .padding(.trailing, 20)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Optionen für \(listName)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

/// Menüeintrag: 48 hoch, padding 0 12, Radius 16, Icon 20 (Strich 1,9, accentText), gap 12, Text 15/500.
private struct ListAccountMenuItem: View {
    let t: ListAccountTokens
    let icon: [SVGElement]
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SVGIcon(icon, size: 20, color: t.accentText, lineWidth: 1.9)
                Text(title)
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(t.k.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 48)
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mitglieder & Teilen

struct ListAccountMember: Identifiable, Hashable {
    let id: UUID
    let name: String
    let role: String
    var initial: String { String(name.prefix(1)).uppercased() }

    init(id: UUID = UUID(), name: String, role: String) {
        self.id = id
        self.name = name
        self.role = role
    }

    static let samples = [ListAccountMember(name: "Rob (Du)", role: "Besitzer")]
}

// Quelle: Design/html/ShareMembers.dc.html (Dark: ShareMembersDark.dc.html)
// Hintergrund: Hybrid (ListScreen) + Standard-Abdunkelung. Sheet 708 hoch, unten bündig.
//   Titelzeile → 20 → „Mitglieder · n“ → 10 → Mitglied-Karte → 10 → gestrichelter Hinweis
//   → 24 → „Einladen“ → 10 → [CTA 56 · 10 · „Link kopieren“ 52 · 10 · Hinweis 13]
//   → 22 → Linie 1 → 18 → öffentliche ID + Kopier-Knopf 44
struct ShareMembersScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var members: [ListAccountMember] = ListAccountMember.samples
    var publicID = "test_public_id"
    var onClose: () -> Void = {}
    var onShareLink: () -> Void = {}
    var onCopyLink: () -> Void = {}
    var onCopyID: () -> Void = {}

    var body: some View {
        let t = ListAccountTokens(appearance, accentHex: accentHex)
        let k = t.k
        let dashed = k.a.base.color(0.4)                     // ShareMembers: dashed = rgba(accent, .4)
        let hintFont = AppFont.ui(.dmSans, 14, 400)
        let idHintFont = AppFont.ui(.dmSans, 12, 400)

        return ListAccountBackdrop(scrim: t.scrimSheet) {
            ListScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            ListAccountSheet(k: k, height: 708, title: "Mitglieder & Teilen", onClose: onClose) {
                ListAccountSectionLabel(text: "Mitglieder · \(members.count)", t: t)
                    .padding(.top, 20)

                VStack(spacing: 10) {
                    ForEach(members) { m in
                        // Karte: padding 13 14 (+1 Rahmen, content-box), Radius 22, gap 14
                        HStack(spacing: 14) {
                            ListAccountAvatar(t: t, initial: m.initial, size: 44, fontSize: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name)
                                    .font(AppFont.outfit(17, 600))
                                    .foregroundStyle(k.text)
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
                }
                .padding(.top, 10)

                if members.count <= 1 {
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

                ListAccountSectionLabel(text: "Einladen", t: t)
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    ListAccountIconCTA(k: k, icon: ListAccountIcon.share, title: "Einladungslink teilen", action: onShareLink)

                    // Sekundär: 52 hoch, Radius 26, Rahmen 1, field, accentText 15/600, Icon 18, gap 10
                    Button(action: onCopyLink) {
                        HStack(spacing: 10) {
                            SVGIcon(ListAccountIcon.copy, size: 18, color: t.accentText, lineWidth: 2)
                            Text("Link kopieren")
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
                            .textSelection(.enabled)
                        Text("Andere können dich damit finden und einladen.")
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                            .cssLineHeight(16.2, font: idHintFont)     // line-height 1.35
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onCopyID) {
                        SVGIcon(ListAccountIcon.copy, size: 18, color: t.accentText, lineWidth: 2)
                            .frame(width: 44, height: 44)
                            .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("ID kopieren")
                }
                .padding(.top, 18)
            }
        }
    }
}

/// Primär-Button mit Icon (wie `CTAButton`, zusätzlich Icon 20 · gap 10, Strich 2 in Button-Textfarbe).
struct ListAccountIconCTA: View {
    let k: SheetTheme
    let icon: [SVGElement]
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SVGIcon(icon, size: 20, color: k.ctaText, lineWidth: 2)
                Text(title)
                    .font(AppFont.dm(16, 600))
                    .foregroundStyle(k.ctaText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(alignment: .top) {
                GlossEllipse(opacity: 0.45)
                    .frame(height: 22)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
            }
            .clipShape(Pill)
            .background(CSSBox(shape: Pill, paint: k.ctaPaint, shadows: k.ctaShadow))
            .contentShape(Pill)
        }
        .buttonStyle(.plain)
    }
}
