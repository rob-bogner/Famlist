/*
 EKKTokens.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zusatz-Tokens der Gruppe „Einstieg, Kategorien, Kassenzettel“ (Hero, Karten, Apple-Knopf, ok/warn).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

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
