/*
 GroceryGenius
 Color.swift
 File Overview:
 This file extends the Color struct to include a custom color theme for the Grocery Genius app.
 Created: 05.01.24
 Last Updated: 27.04.24
*/

import Foundation // Import Foundation framework for basic functionalities
import SwiftUI // Import SwiftUI framework for UI components

/// Provides static access to the app's custom color theme via `Color.theme`.
extension Color { // Extend the Color struct
    /// Provides access to the custom color theme.
    static let theme = ColorTheme() // Define a static constant to access the ColorTheme instance
}

/// Struct defining a custom color theme for the app, pulling colors from the asset catalog.
struct ColorTheme { // Define the ColorTheme struct
    
    // MARK: - Properties
    
    /// Accent color used throughout the app.
    let accent = Color("AccentColor") // Define accent color from asset catalog
    
    /// Background color for views.
    let background = Color("BackgroundColor") // Define background color from asset catalog
    
    /// Color used for card-like elements.
    let card = Color("CardColor") // Define card color from asset catalog
    
    /// Color used for shadows.
    let shadow = Color("ShadowColor") // Define shadow color from asset catalog
    
    /// Fill color for buttons.
    let buttonFillColor = Color("ButtonFillColor") // Define button fill color from asset catalog
    
    /// Color for icons on buttons.
    let buttonIconColor = Color("ButtonIconColor") // Define button icon color from asset catalog
}
