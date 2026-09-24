/*
 SheetTheme.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sämtliche Farb-, Verlaufs- und Schattenwerte der Sheets.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SheetTheme {
    let appearance: Appearance
    let a: AccentScale
    var isDark: Bool { appearance == .dark }

    let sheet: Paint
    let sheetTopBorder: Color
    let sheetShadow: [BoxShadow]
    let text: Color
    let sub: Color
    let close: Color
    let icon: Color
    let grabber: Color
    let scrim: Color
    let field: Color
    let fieldBorder: Color
    let fieldFocus: Color
    let ring: Color
    let ringSoft: Color
    let ringGlow: Color
    let dashed: Color
    let chip: Color
    let stepOff: Color
    let stepOffIcon: Color

    init(_ appearance: Appearance, accentHex: String? = nil) {
        self.appearance = appearance
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        self.a = a
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            sheet = .linear(180, [stop(.hex("#102022"), 0), stop(.hex("#0A1416"), 1)])
            sheetTopBorder = w(0.08)
            // inset 0 1px 0 rgba(255,255,255,.06) wird in SheetSurface unter dem Rahmen gezeichnet
            sheetShadow = [.drop(0, -24, 50, -20, .rgba(0, 0, 0, 0.8))]
            text = .hex("#EAF5F6")
            sub = .hex("#93ADB1")
            close = w(0.08)
            icon = .hex("#D3E6E8")
            grabber = w(0.18)
            scrim = .rgba(0, 0, 0, 0.6)
            field = w(0.05)
            fieldBorder = w(0.09)
            fieldFocus = w(0.06)
            ring = a.base.color(0.7)
            ringSoft = a.base.color(0.12)
            ringGlow = a.base.color(0.4)
            dashed = a.base.color(0.45)
            chip = w(0.05)
            stepOff = w(0.06)
            stepOffIcon = w(0.3)
        } else {
            sheet = .color(.white)
            sheetTopBorder = .clear
            sheetShadow = [.drop(0, -20, 40, -20, .rgba(8, 30, 33, 0.35))]
            text = .hex("#0F2528")
            sub = .hex("#5F7579")
            close = .hex("#F1F5F5")
            icon = .hex("#1E3A3E")
            grabber = .hex("#D5DEDF")
            scrim = .rgba(8, 24, 27, 0.42)
            field = .hex("#F4F7F7")
            fieldBorder = .hex("#E6EDEE")
            fieldFocus = .white
            ring = a.base.color(0.75)
            ringSoft = a.base.color(0.12)
            ringGlow = a.base.color(0.45)
            dashed = a.base.color(0.45)
            chip = .hex("#F4F7F7")
            stepOff = .hex("#E8EEEF")
            stepOffIcon = .hex("#A9B8BA")
        }
    }

    var accent: Color { a.base.color() }
    var accentText: Color { isDark ? a.light.color() : a.deep.color() }

    /// Primär-Button (Glas-Pille)
    var ctaPaint: Paint {
        isDark
            ? .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            : .linear(180, [stop(a.base.color(), 0), stop(a.deep.color(), 1)])
    }
    var ctaText: Color { isDark ? .hex("#04262A") : .white }
    var ctaShadow: [BoxShadow] {
        isDark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)), .drop(0, 10, 20, -12, a.base.color(0.6))]
            : [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.35)),
               .inner(0, -2, 6, 0, .rgba(0, 30, 34, 0.2)),
               .drop(0, 14, 26, -12, a.base.color(0.8))]
    }

    /// Plus-Knopf im Mengen-Stepper
    var stepPaint: Paint {
        .radialCircle(UnitPoint(x: 0.32, y: 0.22), [stop(a.light.color(), 0), stop(a.base.color(), 0.5), stop(a.deep.color(), 1)])
    }
    var stepShadow: [BoxShadow] {
        [.inner(0, -2, 5, 0, .rgba(0, 30, 34, 0.25)), .drop(0, 6, 12, -6, a.base.color(isDark ? 0.5 : 0.8))]
    }
}
