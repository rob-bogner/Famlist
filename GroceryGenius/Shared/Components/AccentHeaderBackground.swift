/*
 AccentHeaderBackground.swift

 GroceryGenius
 Created on: 30.05.2025
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Decorative accent header background with rounded bottom corners and subtle gradient stroke decorations, used at the top of the shopping list screen.

 🛠 Includes:
 - Full-width accent colored background respecting safe area
 - Rounded bottom corners for ticket-style appearance
 - Lightweight decorative overlay (angled lines)
 - Corner rounding helper for specific corners

 🔰 Notes for Beginners:
 - GeometryReader used only to obtain width/height (no preference inference needed)
 - Decorations intentionally minimal; tweak AccentDecorations for branding
 - Corner radius helper centralizes selective rounding logic

 📝 Last Change:
 - Standardized header block formatting. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to build the decorative background view.


/// Background view that paints the accent header with rounded bottom corners and subtle decorations.
struct AccentHeaderBackground: View { // Declares a SwiftUI View for the header background.
    var body: some View { // Body describing layout and drawing.
        GeometryReader { geometry in // Reads container size to size shapes accordingly.
            ZStack { // Overlay shapes in a stack.
                RoundedRectangle(cornerRadius: 22, style: .continuous) // Base rounded rectangle fill.
                    .fill(Color.theme.accent) // Fill with accent color from theme.
                    .frame(width: geometry.size.width, height: geometry.size.height) // Match the available size.
                    .cornerRadius(32, corners: [.bottomLeft, .bottomRight]) // Extra rounding for bottom corners only.
                AccentDecorations(width: geometry.size.width, height: geometry.size.height) // Draw decorative strokes.
            }
            .edgesIgnoringSafeArea(.top) // Extend behind system status bar area at top.
        }
        .frame(height: UIScreen.main.bounds.height * DS.Layout.headerHeightRatio) // Fixed height relative to screen height.
    }
}

/// Lightweight decorative strokes layered over the header background.
private struct AccentDecorations: View { // Private helper view for decorations.
    let width: CGFloat // Available width from parent.
    let height: CGFloat // Available height from parent.
    var body: some View { // Describe decorative shapes.
        ZStack { // Layer multiple strokes.
            RoundedRectangle(cornerRadius: 24) // Outer stroked rounded rect.
                .stroke( // Outline with gradient stroke.
                    LinearGradient( // Horizontal gradient from leading to trailing.
                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.37), Color.pink.opacity(0.37)]), // Soft colors.
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3 // Stroke width.
                )
                .frame(width: width * 0.5, height: 150) // Scale based on container width.
                .rotationEffect(.degrees(-15)) // Tilt slightly for visual interest.
                .offset(x: -width * 0.15, y: 1) // Position to left.

            RoundedRectangle(cornerRadius: 30) // Inner stroked rounded rect.
                .stroke( // Outline with a stronger gradient.
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.6), Color.pink.opacity(0.5)]), // Stronger colors.
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2 // Slightly thinner stroke.
                )
                .frame(width: width * 0.54, height: 112) // Slightly larger width but shorter height.
                .rotationEffect(.degrees(-15)) // Same tilt for consistency.
                .offset(x: width * 0.2, y: 20) // Position to right.
        }
    }
}

// MARK: - Corner Rounding Helper
extension View { func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RoundedCorner(radius: radius, corners: corners)) } } // Convenience to round specific corners by clipping to custom shape.

/// Shape that rounds only selected corners of a rectangle.
private struct RoundedCorner: Shape { // Custom shape for selective corner rounding.
    var radius: CGFloat = .infinity // Corner radius value.
    var corners: UIRectCorner = .allCorners // Which corners to round.
    func path(in rect: CGRect) -> Path { // Required method to draw the shape.
        let path = UIBezierPath( // Use UIBezierPath to create a rounded rect with selected corners.
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath) // Convert to SwiftUI Path for rendering.
    }
}

#Preview { AccentHeaderBackground() } // Preview the decorative background alone.
