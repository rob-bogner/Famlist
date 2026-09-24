/*
 OverlayTheme.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Farb- und Schattenwerte der Overlays (Kontext-Menü, Dock-Menüs, Toasts) inkl. Akzent-Mathematik.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct OverlayTheme {
    /// Menü-Deckkraft: Kontext-Menü oben (MenuOverlay) .95 / .94, Dock-Menüs .97 / .96.
    enum MenuVariant {
        case listMenu
        case dockMenu
    }

    let appearance: Appearance
    let a: AccentScale
    var isDark: Bool { appearance == .dark }

    let text: Color
    let sub: Color
    let scrim: Color
    let line: Color

    let menu: Color
    /// Deckende Menüfarbe für den Zeiger
    let menuSolid: Color
    let menuBorder: Color
    let menuShadow: [BoxShadow]

    let accentText: Color
    /// Hervorgehobene Zeile
    let hi: Color
    let field: Color
    let fieldBorder: Color
    let danger: Color
    let dangerSoft: Color
    let toggleOn: Paint

    let toast: Color
    let toastBorder: Color
    let toastShadow: [BoxShadow]
    let okBg: Color
    let undoBg: Color
    let timer: Color

    /// Aktiver Menü-Knopf (nur MenuOverlay)
    let btn: Color
    let btnRing: Color

    init(_ appearance: Appearance, accentHex: String? = nil, variant: MenuVariant = .dockMenu) {
        self.appearance = appearance
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        self.a = a
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            text = .hex("#EAF5F6")
            sub = .hex("#93ADB1")
            scrim = .rgba(0, 0, 0, 0.45)
            line = w(0.08)
            menu = .rgba(20, 34, 37, variant == .listMenu ? 0.94 : 0.96)
            menuSolid = .hex("#142225")
            menuBorder = w(0.1)
            menuShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 24, 48, -16, .rgba(0, 0, 0, 0.8))]
            accentText = a.light.color()
            hi = a.base.color(0.14)
            field = w(0.05)
            fieldBorder = w(0.08)
            danger = .hex("#FF7A7E")
            dangerSoft = .rgba(255, 122, 126, 0.1)
            toggleOn = .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            toast = .rgba(30, 48, 52, 0.95)
            toastBorder = w(0.12)
            toastShadow = [.inner(0, 1, 0, 0, w(0.1)), .drop(0, 16, 32, -14, .rgba(0, 0, 0, 0.8))]
            okBg = a.base.color(0.18)
            undoBg = a.base.color(0.16)
            timer = a.base.color(0.8)
            btn = .rgba(20, 34, 37, 0.94)
            btnRing = a.base.color(0.6)
        } else {
            text = .hex("#0F2528")
            sub = .hex("#5F7579")
            scrim = .rgba(8, 24, 27, 0.18)
            line = .hex("#EDF1F2")
            menu = .rgba(255, 255, 255, variant == .listMenu ? 0.95 : 0.97)
            menuSolid = .white
            menuBorder = .rgba(15, 37, 40, 0.08)
            menuShadow = [.drop(0, 24, 48, -16, .rgba(12, 40, 44, 0.35))]
            accentText = a.deep.color()
            hi = a.base.color(0.08)
            field = .hex("#F4F7F7")
            fieldBorder = .hex("#E6EDEE")
            danger = .hex("#C8363B")
            dangerSoft = .rgba(200, 54, 59, 0.07)
            toggleOn = .linear(180, [stop(a.base.color(), 0), stop(a.deep.color(), 1)])
            toast = .rgba(15, 27, 29, 0.94)
            toastBorder = w(0.1)
            toastShadow = [.inner(0, 1, 0, 0, w(0.12)), .drop(0, 16, 32, -14, .rgba(12, 30, 33, 0.5))]
            okBg = a.base.color(0.22)
            undoBg = a.base.color(0.18)
            timer = a.base.color(0.9)
            btn = .white
            btnRing = a.base.color(0.55)
        }
    }

    // Toast-Inhalte sind in beiden Modi gleich (dunkles Glas)
    var toastText: Color { .white }
    var toastSub: Color { .rgba(255, 255, 255, 0.65) }
    var toastIcon: Color { .rgba(255, 255, 255, 0.75) }
    /// `light` = mix(accent → Weiß, .32) – Häkchen (CopyDone) und „Rückgängig“ (UndoToast)
    var toastAccent: Color { a.light.color() }
}
