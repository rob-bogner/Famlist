/*
 AccentHeaderBackground.swift

 Famlist
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
import UIKit


/// Background view that paints the accent header with rounded bottom corners and subtle decorations.
struct AccentHeaderBackground: View { // Declares a SwiftUI View for the header background.
    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }

    var body: some View { // Body describing layout and drawing.
        GeometryReader { geometry in // Reads container size to size shapes accordingly.
            ZStack { // Overlay shapes in a stack.
                RoundedRectangle(cornerRadius: 22, style: .continuous) // Base rounded rectangle fill.
                    .fill(Color.theme.accent) // Fill with accent color from theme.
                    .frame(width: geometry.size.width, height: geometry.size.height) // Match the available size.
                    .cornerRadius(32, corners: [.bottomLeft, .bottomRight]) // Extra rounding for bottom corners only.
            }
            .edgesIgnoringSafeArea(.top) // Extend behind system status bar area at top.
        }
        .frame(height: DS.Layout.headerFixedHeight + safeAreaTop) // Fixed height plus safe-area inset for consistent look across devices.
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
