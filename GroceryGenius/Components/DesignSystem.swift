// DesignSystem.swift
// Central design tokens (spacing, radii, animation durations, layout metrics)
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
