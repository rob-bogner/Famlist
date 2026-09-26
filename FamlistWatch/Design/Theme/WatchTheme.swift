/*
 WatchTheme.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Farb-Tokens der Watch-App aus Watch*.dc.html (renderVals → `w`). watchOS ist immer dunkel.

 🔰 Notes for Beginners:
 - Akzent #1FC2CC = dunkler Akzent der iOS-App. Abgeleitete Töne wie AccentScale im iOS-Target:
   light = mix(accent → Weiß, 0.32) · deep = mix(accent → Schwarz, 0.5).
 - Übernommen aus design-handoff/WatchUI/Theme/WatchTheme.swift, Werte unverändert.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchTheme {
    let accent: WatchRGB
    var light: WatchRGB { accent.mix(255, 0.32) }
    var deep: WatchRGB { accent.mix(0, 0.5) }

    init(accentHex: String = "#1FC2CC") { accent = WatchRGB(accentHex) }

    // MARK: Text
    /// Titel, Zahlen, Chip-Text.
    var accentText: Color { light.color() }
    let text = Color.white
    let sub = Color.white.opacity(0.6)
    let faint = Color.white.opacity(0.4)
    let line = Color.white.opacity(0.12)

    // MARK: Flächen (CSS-Werte, gezeichnet mit CSSBox aus dem iOS-Designsystem)
    /// Hintergrund: radial-gradient(120% 70% at 50% 110%, rgba(accent,.16), rgba(0,0,0,0) 60%), #000
    var glow: Color { accent.color(0.16) }
    /// Karte: linear-gradient(180deg, rgba(255,255,255,.14), rgba(255,255,255,.08))
    var card: Paint { .linear(180, [stop(.white.opacity(0.14), 0), stop(.white.opacity(0.08), 1)]) }
    let cardBorder = Color.white.opacity(0.08)
    /// inset 0 1px 0 rgba(255,255,255,.12)
    var cardShadow: BoxShadow { .inner(0, 1, 0, 0, .white.opacity(0.12)) }

    // MARK: Fortschritt
    let track = Color.white.opacity(0.14)
    /// linear-gradient(90deg, light, accent)
    var fill: LinearGradient {
        LinearGradient(colors: [light.color(), accent.color()], startPoint: .leading, endPoint: .trailing)
    }
    /// Kreis offener Artikel: Rand 2 px rgba(accent,.55)
    var ring: Color { accent.color(0.55) }

    // MARK: Knöpfe
    /// FAB / Mikrofon: radial-gradient(circle at 32% 22%, light 0%, accent 45%, deep 100%)
    var fab: Paint { orb(accentStop: 0.45) }
    /// FAB-Schatten: inset 0 -3px 8px rgba(0,30,34,.3), 0 0 14px rgba(accent,.35)
    var fabShadow: [BoxShadow] {
        [.inner(0, -3, 8, 0, Color(.sRGB, red: 0, green: 30 / 255, blue: 34 / 255, opacity: 0.3)),
         .drop(0, 0, 14, 0, accent.color(0.35))]
    }
    /// Erledigt-Kreis: radial-gradient(circle at 32% 22%, light 0%, accent 55%, deep 100%)
    var checkFill: Paint { orb(accentStop: 0.55) }
    /// Glas-Knopf: linear-gradient(180deg, rgba(255,255,255,.2), rgba(255,255,255,.1)), Rand weiß .16
    var glassButton: Paint { .linear(180, [stop(.white.opacity(0.2), 0), stop(.white.opacity(0.1), 1)]) }
    let glassBorder = Color.white.opacity(0.16)
    /// Chip: rgba(accent,.2), Text light
    var chip: Color { accent.color(0.2) }
    /// CTA „Abhaken“: linear-gradient(180deg, light 0%, accent 100%), inset 0 1px 0 rgba(255,255,255,.5)
    var cta: Paint { .linear(180, [stop(light.color(), 0), stop(accent.color(), 1)]) }
    let ctaText = Color(.sRGB, red: 4 / 255, green: 38 / 255, blue: 42 / 255, opacity: 1)

    private func orb(accentStop: Double) -> Paint {
        .radialCircle(UnitPoint(x: 0.32, y: 0.22),
                      [stop(light.color(), 0), stop(accent.color(), accentStop), stop(deep.color(), 1)])
    }
}
