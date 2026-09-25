/*
 ListAccountTokens.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zusatz-Tokens der Gruppe „Listen & Konto“ (Karten, Schalter, Segment, Menü, Abdunkelungen).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

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
