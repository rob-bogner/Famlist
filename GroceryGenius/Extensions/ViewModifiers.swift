// MARK: - Reusable UI Components & Utilities

/// Primary action button used across the app
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8) // doppelte Höhe (vorher 4)
        }
        .buttonStyle(.borderedProminent) // Systemstil beibehalten
        // .controlSize(.small) entfernt, eigene Höhe über Padding
        .frame(maxWidth: .infinity)
    }
}

/// Plus/Minus control for integer quantities
struct QuantityStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var body: some View {
        HStack(spacing: 10) {
            Button("-") { if value > range.lowerBound { value -= 1 } }
            Text("\(value)").frame(minWidth: 40)
            Button("+") { if value < range.upperBound { value += 1 } }
        }
        .font(.title3)
    }
}

/// Card-like progress display
struct ProgressCard: View {
    let title: String
    let progress: Double
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption2).fontWeight(.bold).foregroundColor(Color.theme.background)
            HStack {
                Image(systemName: "basket")
                ProgressView(value: progress)
                Text(label)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.theme.card)
            .cornerRadius(10)
        }
    }
}

/// Consistent section header
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Card style used throughout the app
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

/// Centralized formatters
enum Formatting {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = .current
        return f
    }()
    static func priceText(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? "€ 0,00"
    }
}

/// Measure enum and picker (keeps String in model for now)
enum Measure: String, CaseIterable, Codable { case g, kg, ml, l, stk, pkg }
struct MeasurePicker: View {
    @Binding var selection: String
    var body: some View {
        Picker("Measure", selection: Binding(
            get: { Measure(rawValue: selection) ?? .stk },
            set: { selection = $0.rawValue }
        )) {
            ForEach(Measure.allCases, id: \.self) { m in
                Text(m.rawValue.uppercased()).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Simple image thumbnail
struct Thumbnail: View {
    let image: UIImage?
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "photo")
                    .imageScale(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
    }
}
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
