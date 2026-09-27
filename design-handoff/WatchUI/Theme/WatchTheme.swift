/*
 WatchTheme.swift
 Famlist Watch – Design-Referenz (design-handoff/WatchUI)

 Tokens aus Watch*.dc.html (renderVals → `w`). watchOS ist immer dunkel.
 Akzent: #1FC2CC (dunkler Akzent der iOS-App). Abgeleitete Töne wie AccentScale im iOS-Target:
   light = mix(accent → Weiß, 0.32) · deep = mix(accent → Schwarz, 0.5)
 1 CSS-px = 1 pt · Artboard 208 × 248 (Apple Watch 46 mm).
 */

import SwiftUI

struct WatchRGB {
    let r: Double, g: Double, b: Double
    init(_ hex: String) {
        let s = hex.replacingOccurrences(of: "#", with: "")
        let v = UInt32(s, radix: 16) ?? 0
        r = Double((v >> 16) & 0xFF); g = Double((v >> 8) & 0xFF); b = Double(v & 0xFF)
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    /// JS: Math.round(v + (target - v) * amt)
    func mix(_ target: Double, _ amt: Double) -> WatchRGB {
        func m(_ v: Double) -> Double { (v + (target - v) * amt).rounded(.toNearestOrAwayFromZero) }
        return WatchRGB(r: m(r), g: m(g), b: m(b))
    }
    func color(_ alpha: Double = 1) -> Color { Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha) }
}

struct WatchTheme {
    let accent: WatchRGB
    var light: WatchRGB { accent.mix(255, 0.32) }
    var deep: WatchRGB { accent.mix(0, 0.5) }

    init(accentHex: String = "#1FC2CC") { accent = WatchRGB(accentHex) }

    // Text
    var accentText: Color { light.color() }                         // Titel, Zahlen
    let text = Color.white
    let sub = Color.white.opacity(0.6)
    let faint = Color.white.opacity(0.4)
    let line = Color.white.opacity(0.12)

    // Flächen
    /// Hintergrund: radial-gradient(120% 70% at 50% 110%, rgba(accent,.16), transparent 60%), #000
    var glow: Color { accent.color(0.16) }
    /// Karte: linear-gradient(180deg, rgba(255,255,255,.14), rgba(255,255,255,.08)), Rand 1 px weiß .08,
    /// Schatten inset 0 1 0 weiß .12
    let cardTop = Color.white.opacity(0.14)
    let cardBottom = Color.white.opacity(0.08)
    let cardBorder = Color.white.opacity(0.08)
    let cardInnerHighlight = Color.white.opacity(0.12)

    // Fortschritt
    let track = Color.white.opacity(0.14)
    /// linear-gradient(90deg, light, accent)
    var fill: LinearGradient { LinearGradient(colors: [light.color(), accent.color()], startPoint: .leading, endPoint: .trailing) }
    /// Kreis offener Artikel: Rand 2 px rgba(accent,.55)
    var ring: Color { accent.color(0.55) }

    // Knöpfe
    /// FAB / Abhaken-Kreis: radial-gradient(circle at 32% 22%, light 0%, accent 45% (Haken: 55%), deep 100%)
    func orb(accentStop: Double = 0.45) -> RadialGradient {
        RadialGradient(stops: [.init(color: light.color(), location: 0),
                               .init(color: accent.color(), location: accentStop),
                               .init(color: deep.color(), location: 1)],
                       center: UnitPoint(x: 0.32, y: 0.22), startRadius: 0, endRadius: 34)
    }
    /// FAB-Schatten: inset 0 -3 8 rgba(0,30,34,.3), 0 0 14 rgba(accent,.35)
    var fabGlow: Color { accent.color(0.35) }
    /// Glas-Knopf: linear-gradient(180deg, weiß .2, weiß .1), Rand weiß .16
    let glassTop = Color.white.opacity(0.2)
    let glassBottom = Color.white.opacity(0.1)
    let glassBorder = Color.white.opacity(0.16)
    /// Chip: rgba(accent,.2), Text light
    var chip: Color { accent.color(0.2) }
    /// CTA „Abhaken“: linear-gradient(180deg, light, accent), inset 0 1 0 weiß .5, Text #04262A
    var ctaGradient: LinearGradient { LinearGradient(colors: [light.color(), accent.color()], startPoint: .top, endPoint: .bottom) }
    let ctaText = Color(.sRGB, red: 4 / 255, green: 38 / 255, blue: 42 / 255, opacity: 1)
}

/// Schriften: Outfit (Titel) und DM Sans (Text) wie im iOS-Target – im Watch-Target ebenfalls einbinden
/// (UIAppFonts in der Info.plist des Watch-Targets). Namen prüfen, wie in design-handoff/MyListUI/README.md.
enum WatchFont {
    static func outfit(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .custom("Outfit", size: size).weight(weight) }
    static func dm(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("DM Sans", size: size).weight(weight) }
}
