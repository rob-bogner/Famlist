/*
 BoxShadow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Eintrag einer CSS-box-shadow-Liste (außen oder inset).

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Ein Eintrag einer CSS-`box-shadow`-Liste.
struct BoxShadow {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var blur: CGFloat = 0
    var spread: CGFloat = 0
    var color: Color
    var isInset = false

    /// `x y blur spread color`
    static func drop(_ x: CGFloat, _ y: CGFloat, _ blur: CGFloat, _ spread: CGFloat, _ color: Color) -> BoxShadow {
        BoxShadow(x: x, y: y, blur: blur, spread: spread, color: color, isInset: false)
    }

    /// `inset x y blur spread color`
    static func inner(_ x: CGFloat, _ y: CGFloat, _ blur: CGFloat, _ spread: CGFloat, _ color: Color) -> BoxShadow {
        BoxShadow(x: x, y: y, blur: blur, spread: spread, color: color, isInset: true)
    }
}
