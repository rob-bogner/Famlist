// MARK: - ViewModifiers.swift

/*
 ViewModifiers.swift

 GroceryGenius
 Created on: 20.07.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines reusable ViewModifiers for common styling patterns
 used throughout the Grocery Genius app.

 🛠 Includes:
 - RoundedCornerModifier: Applies rounded corners to views
 - ShadowModifier: Adds a shadow to views
 - CapsuleBorderModifier: Adds a capsule-shaped border

 🔰 Notes for Beginners:
 - ViewModifiers allow you to encapsulate styling logic and reuse it across views.
 - Use `.modifier()` to apply a ViewModifier to a view.
 ------------------------------------------------------------------------
*/

import SwiftUI

/// A ViewModifier that applies rounded corners to a view.
struct RoundedCornerModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .cornerRadius(radius)
    }
}

/// A ViewModifier that adds a shadow to a view.
struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}

/// A ViewModifier that adds a capsule-shaped border to a view.
struct CapsuleBorderModifier: ViewModifier {
    let color: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                Capsule().stroke(color, lineWidth: lineWidth)
            )
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Applies rounded corners to the view.
    func roundedCorners(_ radius: CGFloat) -> some View {
        self.modifier(RoundedCornerModifier(radius: radius))
    }

    /// Applies a shadow to the view.
    func shadowStyle(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        self.modifier(ShadowModifier(color: color, radius: radius, x: x, y: y))
    }

    /// Applies a capsule-shaped border to the view.
    func capsuleBorder(color: Color, lineWidth: CGFloat) -> some View {
        self.modifier(CapsuleBorderModifier(color: color, lineWidth: lineWidth))
    }
}