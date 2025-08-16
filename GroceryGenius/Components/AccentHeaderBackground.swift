//
// GroceryGenius
// AccentHeaderBackground.swift
// Created on: 30.05.2025
//
// ------------------------------------------------------------------------
// 📄 File Overview:
//
// This file defines AccentHeaderBackground, a decorative, ticket-app-style accent
// background with rounded bottom corners and subtle accent lines. It is used as
// the main header background in the shopping list for a visually modern look.
// The background color uses Color.theme.accent for full light/dark support.
//
// ------------------------------------------------------------------------

import SwiftUI

/// AccentHeaderBackground – Decorative header background with accent color,
/// rounded bottom corners, and accent line decorations.
struct AccentHeaderBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main accent background with rounded bottom corners.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.theme.accent)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
                
                // Accent lines/shapes layered on top for subtle decoration.
                AccentDecorations(width: geometry.size.width, height: geometry.size.height)
            }
            .edgesIgnoringSafeArea(.top) // Header covers top safe area.
        }
        .frame(height: UIScreen.main.bounds.height * DS.Layout.headerHeightRatio)
    }
}

/// Subview for accent line decorations (can be tweaked as desired).
struct AccentDecorations: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Example: angled accent line (top left)
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.37), Color.pink.opacity(0.37)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
                .frame(width: width * 0.5, height: 150)
                .rotationEffect(.degrees(-15))
                .offset(x: -width * 0.15, y: 1)
            
            // Example: accent curve (top right)
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.6), Color.pink.opacity(0.5)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .frame(width: width * 0.54, height: 112)
                .rotationEffect(.degrees(-15))
                .offset(x: width * 0.2, y: 20)
        }
    }
}

// Extension for rounding only specific corners (used for bottom corners).
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

/// Helper shape to round only selected corners.
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    AccentHeaderBackground()
}
