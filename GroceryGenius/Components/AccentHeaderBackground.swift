// MARK: - AccentHeaderBackground.swift

/*
 File: AccentHeaderBackground.swift
 Project: GroceryGenius
 Created: 30.05.2025
 Last Updated: 17.08.2025

 Overview:
 Decorative accent header background with rounded bottom corners and subtle gradient stroke decorations, used at the top of the shopping list screen.

 Responsibilities / Includes:
 - Full-width accent colored background respecting safe area
 - Rounded bottom corners for ticket-style appearance
 - Lightweight decorative overlay (angled lines)
 - Corner rounding helper for specific corners

 Design Notes:
 - GeometryReader used only to obtain width/height (no preference inference needed)
 - Decorations intentionally minimal; tweak AccentDecorations for branding
 - Corner radius helper centralizes selective rounding logic

 Possible Enhancements:
 - Add dynamic blur / parallax effects on scroll
 - Extract gradients into design tokens
 - Provide reduced-motion variant for accessibility
*/

import SwiftUI

struct AccentHeaderBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.theme.accent)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
                AccentDecorations(width: geometry.size.width, height: geometry.size.height)
            }
            .edgesIgnoringSafeArea(.top)
        }
        .frame(height: UIScreen.main.bounds.height * DS.Layout.headerHeightRatio)
    }
}

private struct AccentDecorations: View {
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        ZStack {
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

// MARK: - Corner Rounding Helper
extension View { func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RoundedCorner(radius: radius, corners: corners)) } }

private struct RoundedCorner: Shape {
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

// MARK: - Header Style & Composite Header (title + optional progress)
enum AccentHeaderStyle { case withProgress, plain }

struct AccentHeader: View {
    let title: String
    var style: AccentHeaderStyle = .withProgress
    @EnvironmentObject private var listViewModel: ListViewModel

    private var headerHeight: CGFloat { UIScreen.main.bounds.height * DS.Layout.headerHeightRatio }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AccentHeaderBackground()
                .frame(height: headerHeight)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.theme.background)
                    .padding(.top, 30)
                    .padding(.leading, 18)
                if style == .withProgress {
                    ShoppingListProgressView(listViewModel: listViewModel)
                        .padding(.top, 8)
                }
                Spacer(minLength: 4)
            }
            .frame(height: headerHeight, alignment: .top)
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        AccentHeader(title: "Preview", style: .withProgress)
            .environmentObject(ListViewModel(repository: PreviewItemsRepository()))
        Spacer()
    }
}
#endif
