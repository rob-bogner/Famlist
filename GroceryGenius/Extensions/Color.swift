/*
 Color.swift

 GroceryGenius
 Created on: 05.01.2024
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Centralized color theme accessor. Exposes strongly-typed color tokens pulled from the asset catalog to avoid magic strings and scattered color references.

 🛠 Includes:
 - Color.theme namespace and ColorTheme struct listing semantic colors (accent, background, card, etc.).

 🔰 Notes for Beginners:
 - Keep naming semantic (what the color represents, not the shade).
 - Assets must match the string names exactly.

 📝 Last Change:
 - Standardized header format; no functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to access Color and build UI elements.

extension Color { // Extends SwiftUI's Color type with app-specific helpers.
    /// Application design system color namespace.
    static let theme = ColorTheme() // Provides strongly-typed access to our palette via Color.theme.
}

/// Strongly typed palette of semantic colors.
struct ColorTheme { // Groups all color tokens so you don't sprinkle raw asset names in code.
    let accent = Color("AccentColor") // Primary accent color used for highlights and buttons.
    let background = Color("BackgroundColor") // Main app background color.
    let card = Color("CardColor") // Surface color for cards and panels.
    let shadow = Color("ShadowColor") // Shadow tint used across components.
    let buttonFillColor = Color("ButtonFillColor") // Fill color for selected/checked rows.
    let buttonIconColor = Color("ButtonIconColor") // Strike-through and icon tint for checked states.
    let textColor = Color("TextColor") // Primary text color for content on light backgrounds.
    let universalWhite = Color("universalWhite") // Named white to allow light/dark variants in assets.
}
