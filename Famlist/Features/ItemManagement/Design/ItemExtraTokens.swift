/*
 ItemExtraTokens.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Farb-Tokens der Screens Artikel verwalten, Barcode-Scanner und Preisverlauf (renderVals()).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ItemExtraScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Tokens (aus renderVals() der drei Quelldateien)

struct ItemExtraTokens {
    let card: Paint
    let cardBorder: Color
    let cardShadow: [BoxShadow]
    let thumb: Paint
    let thumbShadow: [BoxShadow]
    let thumbIcon: Color
    let chipOnBg: Paint
    let chipOnText: Color
    let chipOffBg: Color
    let fade: [Gradient.Stop]
    let line: Color
    let menu: Color
    let menuBorder: Color
    let tile: Paint
    let ok: Color
    let okSoft: Color
    let dotFill: Color
    let areaFill: Color

    init(_ appearance: Appearance, accentHex: String? = nil) {
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            card = .linear(180, [stop(w(0.07), 0), stop(w(0.03), 1)])
            cardBorder = w(0.08)
            cardShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            thumb = .linear(150, [stop(a.base.color(0.22), 0), stop(a.base.color(0.06), 1)])
            thumbShadow = [.inner(0, 1, 0, 0, w(0.12))]
            thumbIcon = a.light.color()
            chipOnBg = .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            chipOnText = .hex("#04262A")
            chipOffBg = w(0.05)
            fade = [stop(.rgba(10, 20, 22, 0), 0), stop(.hex("#0A1416"), 0.85)]
            line = w(0.08)
            menu = .rgba(20, 34, 37, 0.97)
            menuBorder = w(0.1)
            tile = .linear(150, [stop(a.base.color(0.24), 0), stop(a.base.color(0.06), 1)])
            ok = .hex("#4FD1A1")
            okSoft = .rgba(79, 209, 161, 0.14)
            dotFill = .hex("#0A1416")
            areaFill = a.base.color(0.16)
        } else {
            card = .color(.white)
            cardBorder = .hex("#EDF2F2")
            cardShadow = [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
            thumb = .linear(150, [stop(.hex("#F2F7F7"), 0), stop(.hex("#E4EEEF"), 1)])
            thumbShadow = [.inner(0, 1, 0, 0, .white)]
            thumbIcon = .hex("#7D9498")
            chipOnBg = .linear(180, [stop(a.base.color(), 0), stop(a.deep.color(), 1)])
            chipOnText = .white
            chipOffBg = .hex("#F4F7F7")
            fade = [stop(.rgba(255, 255, 255, 0), 0), stop(.white, 0.85)]
            line = .hex("#EDF1F2")
            menu = .rgba(255, 255, 255, 0.97)
            menuBorder = .rgba(15, 37, 40, 0.08)
            tile = .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)])
            ok = .hex("#1F8A5B")
            okSoft = .rgba(31, 138, 91, 0.1)
            dotFill = .white
            areaFill = a.base.color(0.12)
        }
    }
}
