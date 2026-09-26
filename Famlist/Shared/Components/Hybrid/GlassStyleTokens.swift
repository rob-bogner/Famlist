/*
 GlassStyleTokens.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Farbwerte der Glas-Knöpfe (rund: GlassOrb, Pille: GlassPillBackground) – 1:1 aus den Canvas-Token
   gp (Akzent), gn (neutral), gnd (neutral dunkel), gd (Gefahr), ga (Apple: Schwarz hell / Weiß dunkel).

 🔰 Notes for Beginners:
 - Runde Knöpfe: radialer Verlauf „circle at 32% 22%“. Pillen: senkrechter Verlauf (180°).
 - Glanz = Deckkraft der Glanz-Ellipse oben, Schein = weicher Lichtsaum unten.

 📝 Last Change:
 - Initial creation (einheitliche Glas-Knöpfe auf allen Screens).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct GlassStyleTokens {
    let style: GlassOrb.Style
    let appearance: Appearance
    let accent: AccentScale

    /// Neutral hell nur im hellen Modus; Kamera/Fotos immer dunkel.
    private var darkNeutral: Bool { style == .neutralDark || (style == .neutral && appearance == .dark) }
    private var isDark: Bool { appearance == .dark }

    private var stops: [Gradient.Stop] {
        switch style {
        case .accent:
            return [stop(accent.light.color(), 0), stop(accent.base.color(), 0.45), stop(accent.deep.color(), 1)]
        case .danger:
            return [stop(.hex("#FF8A80"), 0), stop(.hex("#E5484D"), 0.55), stop(.hex("#B4232A"), 1)]
        case .apple:
            return appleStops
        case .neutral, .neutralDark:
            return darkNeutral
                ? [stop(.hex("#41575B"), 0), stop(.hex("#1F3033"), 0.5), stop(.hex("#111C1E"), 1)]
                : [stop(.hex("#FFFFFF"), 0), stop(.hex("#EEF4F5"), 0.5), stop(.hex("#D3DFE1"), 1)]
        }
    }

    /// Apple-Vorgabe: Grundfarbe Schwarz bzw. Weiß, nur der Glanz kommt dazu.
    private var appleStops: [Gradient.Stop] {
        isDark
            ? [stop(.hex("#FFFFFF"), 0), stop(.hex("#F3F5F5"), 0.55), stop(.hex("#DDE3E4"), 1)]
            : [stop(.hex("#3A3F40"), 0), stop(.hex("#0B0D0E"), 0.5), stop(.hex("#000000"), 1)]
    }

    var orbPaint: Paint { .radialCircle(UnitPoint(x: 0.32, y: 0.22), stops) }

    var pillPaint: Paint {
        switch style {
        case .accent:
            return .linear(180, [stop(accent.light.color(), 0), stop(accent.base.color(), 0.5), stop(accent.deep.color(), 1)])
        case .danger:
            return .linear(180, [stop(.hex("#FF8A80"), 0), stop(.hex("#E5484D"), 0.55), stop(.hex("#B4232A"), 1)])
        case .apple:
            return .linear(180, appleStops)
        case .neutral, .neutralDark:
            return darkNeutral
                ? .linear(180, [stop(.hex("#33474A"), 0), stop(.hex("#1F3033"), 0.55), stop(.hex("#152326"), 1)])
                : .linear(180, [stop(.hex("#FFFFFF"), 0), stop(.hex("#EEF4F5"), 0.55), stop(.hex("#DCE6E8"), 1)])
        }
    }

    var shadows: [BoxShadow] {
        switch style {
        case .accent:
            return isDark
                ? [.inner(0, -3, 6, 0, .rgba(0, 30, 34, 0.3)), .drop(0, 8, 14, -7, accent.base.color(0.55))]
                : [.inner(0, -3, 6, 0, .rgba(0, 30, 34, 0.3)), .drop(0, 8, 16, -6, accent.base.color(0.7)),
                   .drop(0, 0, 18, 0, accent.base.color(0.25))]
        case .danger:
            return [.inner(0, -3, 6, 0, .rgba(0, 0, 0, 0.18)), .inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.4)),
                    .drop(0, 10, 20, -10, .rgba(229, 72, 77, 0.6))]
        case .apple:
            return isDark
                ? [.inner(0, -3, 6, 0, .rgba(12, 40, 44, 0.12)), .drop(0, 1, 2, 0, .rgba(0, 0, 0, 0.2)),
                   .drop(0, 10, 20, -10, .rgba(0, 0, 0, 0.7))]
                : [.inner(0, -3, 6, 0, .rgba(0, 0, 0, 0.4)), .inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.14)),
                   .drop(0, 10, 20, -10, .rgba(0, 0, 0, 0.55))]
        case .neutral, .neutralDark:
            return darkNeutral
                ? [.inner(0, -3, 6, 0, .rgba(0, 0, 0, 0.35)), .inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)),
                   .drop(0, 8, 16, -8, .rgba(0, 0, 0, 0.8))]
                : [.inner(0, -3, 6, 0, .rgba(12, 40, 44, 0.12)), .drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.08)),
                   .drop(0, 8, 16, -8, .rgba(12, 40, 44, 0.35))]
        }
    }

    var gloss: Double {
        switch style {
        case .accent: return 0.6
        case .danger: return 0.5
        case .apple: return isDark ? 0.95 : 0.3
        case .neutral, .neutralDark: return darkNeutral ? 0.28 : 0.95
        }
    }

    var glow: Double {
        switch style {
        case .accent: return 0.22
        case .danger: return 0.2
        case .apple: return isDark ? 0.6 : 0.12
        case .neutral, .neutralDark: return darkNeutral ? 0.1 : 0.6
        }
    }

    var icon: Color {
        switch style {
        case .accent, .danger: return .white
        case .apple: return isDark ? .black : .white
        case .neutral, .neutralDark: return darkNeutral ? .hex("#D3E6E8") : .hex("#1E3A3E")
        }
    }

    var iconShadow: Color {
        switch style {
        case .accent: return .rgba(0, 40, 45, 0.35)
        case .danger: return .rgba(80, 0, 0, 0.3)
        case .apple: return .clear
        case .neutral, .neutralDark: return .clear
        }
    }
}
