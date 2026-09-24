//  Theme.swift
//  MyListUI
//
//  Sämtliche Farb-, Verlaufs- und Schattenwerte des Hybrid-Designs.
//  Alles, was vom Akzent abhängt, wird mit derselben Mathematik wie im Design berechnet:
//    light  = mix(accent → Weiß, 0,32)
//    deep   = mix(accent → Schwarz, Light 0,40 / Dark 0,50)
//    deeper = mix(accent → Schwarz, 0,60)
//  Standard-Akzent: Light #0FA3AE, Dark #1FC2CC.

import SwiftUI

enum Appearance {
    case light
    case dark

    var defaultAccent: String { self == .light ? "#0FA3AE" : "#1FC2CC" }
}

struct AccentScale {
    let base: RGB
    let light: RGB
    let deep: RGB
    let deeper: RGB

    init(_ hex: String, _ appearance: Appearance) {
        base = RGB(hex: hex)
        light = base.mix(toward: 255, 0.32)
        deep = base.mix(toward: 0, appearance == .dark ? 0.5 : 0.4)
        deeper = base.mix(toward: 0, 0.6)
    }
}

// MARK: - Listen-Screen

struct ListTheme {
    let appearance: Appearance
    let a: AccentScale
    var isDark: Bool { appearance == .dark }

    let text: Color
    let sub: Color
    let icon: Color
    let line: Color

    let round: Paint
    let roundBorder: Color
    let roundShadow: [BoxShadow]

    let search: Color
    let searchBorder: Color
    let searchShadow: [BoxShadow]
    let scanBg: Color

    let card: Paint
    let cardBorder: Color
    let cardShadow: [BoxShadow]
    let thumb: Paint
    let thumbShadow: [BoxShadow]
    let thumbIcon: Color
    let chipBg: Color
    let chipInset: [BoxShadow]
    let checkRing: Color
    let checkBg: Color
    let checkShadow: [BoxShadow]

    let nav: Color
    let navBorder: Color
    let navShadow: [BoxShadow]
    let navActive: Paint
    let navActiveText: Color
    let navActiveShadow: [BoxShadow]
    let navIcon: Color

    init(_ appearance: Appearance, accentHex: String? = nil) {
        self.appearance = appearance
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        self.a = a
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            text = .hex("#EAF5F6")
            sub = .hex("#93ADB1")
            icon = .hex("#D3E6E8")
            line = w(0.08)
            round = .linear(180, [stop(w(0.1), 0), stop(w(0.04), 1)])
            roundBorder = w(0.1)
            roundShadow = [.inner(0, 1, 0, 0, w(0.1)), .drop(0, 8, 20, -8, .rgba(0, 0, 0, 0.7))]
            search = w(0.05)
            searchBorder = w(0.08)
            searchShadow = [.inner(0, 1, 0, 0, w(0.05))]
            scanBg = a.base.color(0.16)
            card = .linear(180, [stop(w(0.075), 0), stop(w(0.03), 1)])
            cardBorder = w(0.09)
            cardShadow = [.inner(0, 1, 0, 0, w(0.1)), .drop(0, 18, 36, -12, .rgba(0, 0, 0, 0.7))]
            thumb = .linear(150, [stop(a.base.color(0.22), 0), stop(a.base.color(0.06), 1)])
            thumbShadow = [.inner(0, 1, 0, 0, w(0.12)), .inner(0, -8, 16, 0, .rgba(0, 0, 0, 0.25))]
            thumbIcon = a.light.color()
            chipBg = a.base.color(0.16)
            chipInset = [.inner(0, 0, 0, 1, a.base.color(0.3))]
            checkRing = a.base.color(0.55)
            checkBg = .rgba(0, 0, 0, 0.25)
            checkShadow = [.inner(0, 2, 4, 0, .rgba(0, 0, 0, 0.5)), .drop(0, 0, 14, 0, a.base.color(0.25))]
            nav = .rgba(22, 36, 39, 0.78)
            navBorder = w(0.1)
            navShadow = [.inner(0, 1, 0, 0, w(0.1)), .drop(0, 24, 44, -12, .rgba(0, 0, 0, 0.85))]
            navActive = .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            navActiveText = .hex("#04262A")
            navActiveShadow = [.inner(0, 1, 0, 0, w(0.5)), .drop(0, 0, 20, 0, a.base.color(0.45))]
            navIcon = .hex("#D3E6E8")
        } else {
            text = .hex("#0F2528")
            sub = .hex("#5F7579")
            icon = .hex("#1E3A3E")
            line = .hex("#EDF1F2")
            round = .color(.white)
            roundBorder = .hex("#E7EEEF")
            roundShadow = [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 8, 18, -8, .rgba(12, 40, 44, 0.18))]
            search = .hex("#F4F7F7")
            searchBorder = .hex("#EAF0F0")
            searchShadow = [.inner(0, 1, 2, 0, .rgba(12, 40, 44, 0.04))]
            scanBg = .white
            card = .color(.white)
            cardBorder = .hex("#EDF2F2")
            cardShadow = [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 14, 32, -14, .rgba(12, 40, 44, 0.22))]
            thumb = .linear(150, [stop(.hex("#F2F7F7"), 0), stop(.hex("#E4EEEF"), 1)])
            thumbShadow = [.inner(0, 1, 0, 0, .white), .inner(0, -4, 10, 0, .rgba(12, 40, 44, 0.05))]
            thumbIcon = .hex("#7D9498")
            chipBg = a.base.color(0.1)
            chipInset = [.inner(0, 0, 0, 1, a.base.color(0.16))]
            checkRing = .hex("#CFDCDE")
            checkBg = .white
            checkShadow = [.inner(0, 2, 3, 0, .rgba(12, 40, 44, 0.08))]
            nav = .hex("#0F1B1D")
            navBorder = w(0.06)
            navShadow = [.inner(0, 1, 0, 0, w(0.12)), .drop(0, 20, 36, -12, .rgba(12, 30, 33, 0.55))]
            navActive = .color(.white)
            navActiveText = .hex("#0F1B1D")
            navActiveShadow = [.inner(0, -2, 0, 0, .rgba(12, 40, 44, 0.08)), .drop(0, 4, 12, 0, .rgba(0, 0, 0, 0.25))]
            navIcon = w(0.86)
        }
    }

    // Akzent-abgeleitet
    var accent: Color { a.base.color() }
    var accentText: Color { isDark ? a.light.color() : a.deep.color() }
    var accentGlow: Color { a.base.color(0.6) }
    var glowA: Color { a.base.color(0.22) }

    var heroBg: Paint {
        .linear(150, [stop(a.light.color(), 0), stop(a.base.color(), 0.42), stop((isDark ? a.deeper : a.deep).color(), 1)])
    }
    var heroShadow: [BoxShadow] {
        [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.35)),
         .inner(0, -1, 0, 0, .rgba(0, 30, 34, 0.2)),
         .drop(0, 22, 40, -16, a.base.color(isDark ? 0.6 : 0.65))]
    }
    var chipGrad: Paint { .linear(150, [stop(a.light.color(), 0), stop(a.deep.color(), 1)]) }
    var chipShadow: [BoxShadow] {
        [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)), .drop(0, 6, 14, -4, a.base.color(0.6))]
    }
    var fabBg: Paint {
        .radialCircle(UnitPoint(x: 0.32, y: 0.22), [stop(a.light.color(), 0), stop(a.base.color(), 0.45), stop(a.deep.color(), 1)])
    }
    var fabShadow: [BoxShadow] {
        isDark
            ? [.inner(0, -4, 10, 0, .rgba(0, 30, 34, 0.3)),
               .drop(0, 12, 22, -10, a.base.color(0.55)),
               .drop(0, 0, 14, 0, a.base.color(0.18))]
            : [.inner(0, -4, 10, 0, .rgba(0, 30, 34, 0.3)),
               .drop(0, 16, 28, -8, a.base.color(0.75)),
               .drop(0, 0, 36, 0, a.base.color(0.35))]
    }
}

// MARK: - Sheets (Produktbild, Suchen, Neuer Artikel, Bearbeiten)

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
