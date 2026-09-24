/*
 AccentScale.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Aus dem Akzent abgeleitete Farbstufen light/deep/deeper (Design-Mathematik).

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

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
