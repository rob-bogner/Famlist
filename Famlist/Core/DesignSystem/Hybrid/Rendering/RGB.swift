/*
 RGB.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - sRGB-Farbwert mit derselben Misch-Mathematik wie das Design (JS Math.round).

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// sRGB-Wert mit Kanälen 0…255 – identische Mathematik wie im Design (JS `Math.round`).
struct RGB: Hashable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt32(s, radix: 16) ?? 0
        self.init(Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
    }

    /// JS: `Math.round(v + (target - v) * amount)` pro Kanal.
    func mix(toward target: Double, _ amount: Double) -> RGB {
        func m(_ v: Double) -> Double { (v + (target - v) * amount).rounded(.toNearestOrAwayFromZero) }
        return RGB(m(r), m(g), m(b))
    }

    func color(_ alpha: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }
}
