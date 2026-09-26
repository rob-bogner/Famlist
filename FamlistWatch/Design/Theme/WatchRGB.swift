/*
 WatchRGB.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - RGB-Farbe mit der Misch-Rechnung des Designs (renderVals in Watch*.dc.html).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/WatchUI/Theme/WatchTheme.swift. JS rundet mit Math.round,
   deshalb .toNearestOrAwayFromZero.
 ------------------------------------------------------------------------
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

    func color(_ alpha: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }
}
