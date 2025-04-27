/*
 GroceryGenius
 Color.swift
 Created by Robert Bogner on 05.01.24.

 Extends the Color struct to include a custom color theme for the Grocery Genius app.
*/

import Foundation
import SwiftUI

/// Provides static access to the app's custom color theme via `Color.theme`.
extension Color {
    /// Provides access to the custom color theme.
    static let theme = ColorTheme()
}

/// Struct defining a custom color theme for the app, pulling colors from the asset catalog.
struct ColorTheme {
    
    // MARK: - Properties
    
    /// Accent color used throughout the app.
    let accent = Color("AccentColor")
    
    /// Background color for views.
    let background = Color("BackgroundColor")
    
    /// Color used for card-like elements.
    let card = Color("CardColor")
    
    /// Color used for shadows.
    let shadow = Color("ShadowColor")
    
    /// Fill color for buttons.
    let buttonFillColor = Color("ButtonFillColor")
    
    /// Color for icons on buttons.
    let buttonIconColor = Color("ButtonIconColor")
    
    // Note: The actual color values are expected to be defined in the asset catalog.
    // The string identifiers ("AccentColor", "BackgroundColor", etc.) should correspond
    // to color set names in the asset catalog.
}
