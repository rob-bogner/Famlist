// MARK: - Color.swift

/*
 File: Color.swift
 Project: GroceryGenius
 Created: 05.01.2024
 Last Updated: 17.08.2025

 Overview:
 Centralized color theme accessor. Exposes strongly-typed color tokens pulled from the asset catalog to avoid magic strings and scattered color references.

 Responsibilities / Includes:
 - Color.theme namespace
 - ColorTheme struct listing semantic colors (accent, background, card, etc.)

 Design Notes:
 - Keep naming semantic (what the color represents, not the shade)
 - Add new colors only here to maintain discoverability
 - Assets must match the string names exactly

 Possible Enhancements:
 - Provide dynamic variants (e.g. elevated surfaces) if needed later
*/

import SwiftUI

extension Color {
    /// Application design system color namespace.
    static let theme = ColorTheme()
}

/// Strongly typed palette of semantic colors.
struct ColorTheme {
    let accent = Color("AccentColor")
    let background = Color("BackgroundColor")
    let card = Color("CardColor")
    let shadow = Color("ShadowColor")
    let buttonFillColor = Color("ButtonFillColor")
    let buttonIconColor = Color("ButtonIconColor")
    let textColor = Color("TextColor")
    let universalWhite = Color("universalWhite")
}
