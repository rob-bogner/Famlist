/*
 ActionCardTokens.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Farben der Aktionskarte (Canvas-Token `dc.*`): Fläche, Rand, Schatten, Abdunkelung, Töne.

 🔰 Notes for Beginners:
 - Fläche/Rand/Schatten wie die Karte „Artikel erkannt“ im Barcode-Scanner (k.menu …).
 - Töne: Gefahr (rot), Warnung (orange), Info (Akzent) – jeweils Kachel-Hintergrund und Symbolfarbe.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Colors of the action card (canvas tokens `dc.*`).
struct ActionCardTokens {
    let scrim: Color
    let background: Color
    let border: Color
    let shadow: [BoxShadow]
    let text: Color
    let sub: Color
    let line: Color
    let field: Color
    let fieldBorder: Color
    let danger: Color
    let dangerSoft: Color
    let warn: Color
    let warnSoft: Color
    let info: Color
    let infoSoft: Color
    let chip: Color
    let strike: Color
    /// Preis gesunken (grün).
    let ok: Color

    init(_ k: SheetTheme) {
        if k.isDark {
            scrim = .rgba(0, 0, 0, 0.55)
            background = .rgba(20, 34, 37, 0.97)
            border = .rgba(255, 255, 255, 0.1)
            shadow = [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 24, 48, -16, .rgba(0, 0, 0, 0.8))]
            text = .hex("#EAF5F6")
            sub = .hex("#93ADB1")
            line = .rgba(255, 255, 255, 0.08)
            field = .rgba(255, 255, 255, 0.05)
            fieldBorder = .rgba(255, 255, 255, 0.09)
            danger = .hex("#FF7A7E")
            dangerSoft = .rgba(255, 122, 126, 0.14)
            warn = .hex("#F2B24C")
            warnSoft = .rgba(242, 178, 76, 0.14)
            info = k.a.light.color()
            infoSoft = k.a.base.color(0.16)
            chip = k.a.base.color(0.16)
            strike = .rgba(147, 173, 177, 0.8)
            ok = .hex("#4FD1A1")
        } else {
            scrim = .rgba(8, 24, 27, 0.42)
            background = .rgba(255, 255, 255, 0.97)
            border = .rgba(15, 37, 40, 0.08)
            shadow = [.drop(0, 24, 48, -16, .rgba(12, 40, 44, 0.35))]
            text = .hex("#0F2528")
            sub = .hex("#5F7579")
            line = .hex("#EDF1F2")
            field = .hex("#F4F7F7")
            fieldBorder = .hex("#E6EDEE")
            danger = .hex("#C8363B")
            dangerSoft = .rgba(200, 54, 59, 0.08)
            warn = .hex("#B7791F")
            warnSoft = .rgba(183, 121, 31, 0.1)
            info = k.a.deep.color()
            infoSoft = k.a.base.color(0.1)
            chip = k.a.base.color(0.1)
            strike = .rgba(95, 117, 121, 0.8)
            ok = .hex("#1F8A5B")
        }
    }

    func color(_ tone: ActionCardTone) -> Color {
        switch tone {
        case .danger: return danger
        case .warn: return warn
        case .info: return info
        }
    }

    func soft(_ tone: ActionCardTone) -> Color {
        switch tone {
        case .danger: return dangerSoft
        case .warn: return warnSoft
        case .info: return infoSoft
        }
    }
}
