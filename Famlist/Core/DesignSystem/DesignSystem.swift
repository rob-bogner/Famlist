/*
 DesignSystem.swift

 GroceryGenius
 Created on: 08.01.2024
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Central design tokens collected in one namespace (DS) to prevent magic numbers for spacing, radii, animation durations and layout metrics.

 🛠 Includes:
 - Spacing scale (4 → 32)
 - Corner radius scale
 - Animation duration presets
 - Layout constants (header ratio, quick add height, image sizes)

 🔰 Notes for Beginners:
 - Use tokens instead of hard-coded numbers in UI code to ensure visual consistency.
 - Ratio based header height keeps proportional feel across devices.

 📝 Last Change:
 - Standardized header and kept token definitions unchanged.
 ------------------------------------------------------------------------
 */
import SwiftUI // Imports SwiftUI for CGFloat, CGSize types used in tokens.

/// Namespace for design tokens to keep magic numbers out of UI code.
struct DS { // DS groups spacing, radius, animation, and layout constants.
    /// Spacing scale used for consistent padding/margins.
    struct Spacing { // Predefined spacing values from tiny to xxl.
        static let xs: CGFloat = 4 // Extra small spacing (e.g., tiny gaps)
        static let s: CGFloat = 8 // Small spacing
        static let m: CGFloat = 12 // Medium spacing
        static let l: CGFloat = 16 // Large spacing, common padding
        static let xl: CGFloat = 24 // Extra-large spacing
        static let xxl: CGFloat = 32 // 2x extra-large spacing
    }
    /// Corner radius scale for rounded shapes.
    struct Radius { // Consistent radii across components.
        static let small: CGFloat = 6 // Small corner radius
        static let medium: CGFloat = 10 // Medium corner radius
        static let large: CGFloat = 22 // Large corner radius
        static let xl: CGFloat = 32 // Extra-large corner radius
    }
    /// Animation durations used across the UI.
    struct Anim { // Speed presets for animations.
        static let fast: Double = 0.18 // Snappy animations
        static let normal: Double = 0.30 // Default animation duration
        static let slow: Double = 0.55 // Noticeable, slow animations
    }
    /// Layout metrics (sizes and ratios).
    struct Layout { // Common dimensions maintaining visual rhythm.
        static let headerHeightRatio: CGFloat = 0.24 // Portion of screen height used by accent header
        static let quickAddHeight: CGFloat = 48 // Height for quick-add control area
        static let itemImage: CGSize = .init(width: 50, height: 50) // Small item image size
        static let thumbnail: CGSize = .init(width: 100, height: 100) // Larger thumbnail size
    }
    
    /// List-specific styling tokens for iOS-version-agnostic appearance.
    struct List { // Controls spacing and insets within SwiftUI Lists.
        static let rowSpacing: CGFloat = 4 // Consistent vertical spacing between list rows across iOS versions (compact)
        static let rowInsets: EdgeInsets = EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16) // Uniform row insets (compact)
        static let sectionSpacing: CGFloat = 16 // Spacing between sections in the list
    }
}
