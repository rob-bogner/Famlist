/*
 SVGElement.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Element eines SVG-Icons: path, circle oder rect.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

enum SVGElement {
    case path(String)
    /// `<circle cx cy r>`
    case circle(CGFloat, CGFloat, CGFloat)
    /// `<rect x y width height rx>`
    case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
}
