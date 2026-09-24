/*
 Appearance.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Light/Dark-Variante des Hybrid-Designs inkl. Standard-Akzentfarbe.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

enum Appearance {
    case light
    case dark

    var defaultAccent: String { self == .light ? "#0FA3AE" : "#1FC2CC" }

    /// Leitet die Variante aus dem System-Erscheinungsbild ab (`@Environment(\.colorScheme)`).
    init(_ colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }
}
