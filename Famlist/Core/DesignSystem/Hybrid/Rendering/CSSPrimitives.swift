/*
 CSSPrimitives.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - CSS-Kurzformen: Color.hex/rgba, Verlaufs-Stopp stop(), Formen RR() und Pill.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

extension Color {
    /// `#RRGGBB` mit optionalem Alpha.
    static func hex(_ hex: String, _ alpha: Double = 1) -> Color { RGB(hex: hex).color(alpha) }

    /// CSS `rgba(r, g, b, a)`.
    static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

/// Kurzform für einen Verlaufs-Stopp.
func stop(_ color: Color, _ location: CGFloat) -> Gradient.Stop {
    Gradient.Stop(color: color, location: location)
}

/// CSS `border-radius: r` (kreisförmige Ecken).
func RR(_ radius: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: radius, style: .circular)
}

/// CSS `border-radius: 999px` bzw. 50 % auf Pillen.
var Pill: Capsule { Capsule(style: .circular) }
