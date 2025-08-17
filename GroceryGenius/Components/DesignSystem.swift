// MARK: - DesignSystem.swift

/*
 File: DesignSystem.swift
 Project: GroceryGenius
 Created: 08.01.2024
 Last Updated: 17.08.2025

 Overview:
 Central design tokens collected in one namespace (DS) to prevent magic numbers for spacing, radii, animation durations and layout metrics.

 Responsibilities / Includes:
 - Spacing scale (4 → 32)
 - Corner radius scale
 - Animation duration presets
 - Layout constants (header ratio, quick add height, image sizes)

 Design Notes:
 - Use tokens instead of hard-coded numbers in UI code to ensure visual consistency.
 - Ratio based header height keeps proportional feel across devices.

 Possible Enhancements:
 - Add typography scale
 - Add elevation / shadow tokens
 - Add semantic spacing aliases (e.g. formRow, sectionGap)
*/
import SwiftUI

struct DS {
    struct Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    struct Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 22
        static let xl: CGFloat = 32
    }
    struct Anim {
        static let fast: Double = 0.18
        static let normal: Double = 0.30
        static let slow: Double = 0.55
    }
    struct Layout {
        static let headerHeightRatio: CGFloat = 0.24
        static let quickAddHeight: CGFloat = 48
        static let itemImage: CGSize = .init(width: 50, height: 50)
        static let thumbnail: CGSize = .init(width: 100, height: 100)
    }
}
