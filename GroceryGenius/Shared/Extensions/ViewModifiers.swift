/*
 ViewModifiers.swift

 GroceryGenius
 Created on: 20.07.2025
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Collection of small reusable SwiftUI building blocks (buttons, steppers, progress card, section header) plus formatting helpers, measurement enum & picker, thumbnail and style modifiers.

 🛠 Includes:
 - PrimaryButton, QuantityStepper, ProgressCard, SectionHeader
 - CardStyle + convenience view modifiers (roundedCorners, shadowStyle, capsuleBorder)
 - Formatting namespace (currency formatter + priceText)
 - Measure enum (localization + normalization) & MeasurePicker
 - Generic Thumbnail component

 🔰 Notes for Beginners:
 - Keep visual tokens (spacing, radii) external (DesignSystem) except minimal inline values.
 - Measure stored as raw String in the model for backward compatibility; enum normalizes user input.
 - Formatting isolated to enable future NumberFormatter reuse/caching.

 📝 Last Change:
 - Replaced ad-hoc header with standardized block and added a preview section using PreviewMocks.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to access views and modifiers used below.

// MARK: - Reusable UI Components
struct PrimaryButton: View { // Prominent full-width button used across modals
    let title: String // Text shown on the button
    let action: () -> Void // Action executed when tapped
    var body: some View { // Declares the view's layout content
        Button(action: action) { // Tappable control
            Text(title) // Label text
                .fontWeight(.semibold) // Slightly bolder text
                .frame(maxWidth: .infinity) // Stretch to full width
                .padding(.vertical, 8) // Vertical padding for touch target
        }
        .buttonStyle(.borderedProminent) // Use platform prominent style
        .frame(maxWidth: .infinity) // Ensure full width in stacks
    }
}

struct QuantityStepper: View { // Simple minus/plus control for integers
    @Binding var value: Int // Two-way value binding
    var range: ClosedRange<Int> = 0...999 // Allowed range
    var body: some View { // Defines the on-screen UI
        HStack(spacing: 10) { // Horizontal layout for - label +
            Button("-") { if value > range.lowerBound { value -= 1 } } // Decrement with lower bound guard
            Text("\(value)").frame(minWidth: 40) // Current value, fixed min width to avoid jumps
            Button("+") { if value < range.upperBound { value += 1 } } // Increment with upper bound guard
        }
        .font(.title3) // Slightly larger tap targets
    }
}

struct ProgressCard: View { // Compact card showing progress percent with icon and label
    let title: String // Small caption
    let progress: Double // 0...1 fraction
    let label: String // Human-readable label, e.g., "3 of 10"
    var body: some View { // Declares the layout
        VStack(alignment: .leading, spacing: 8) { // Stack caption above content row
            Text(title).font(.caption2).fontWeight(.bold).foregroundColor(Color.theme.background) // Upper caption
            HStack { // Content row
                Image(systemName: "basket") // Icon for shopping context
                ProgressView(value: progress) // Native progress bar
                Text(label) // Label to the right
            }
            .padding(.horizontal, 8) // Inner horizontal padding
            .padding(.vertical, 8) // Inner vertical padding
            .frame(maxWidth: .infinity) // Expand to width
            .background(Color.theme.card) // Card background color
            .cornerRadius(10) // Rounded corners
        }
    }
}

struct SectionHeader: View { // List section title helper
    let title: String // Section title text
    var body: some View { // Declares layout
        HStack { // Title with spacer
            Text(title).font(.subheadline).foregroundStyle(.secondary) // Subtle header text
            Spacer() // Pushes text to leading edge
        }
        .padding(.horizontal, 16) // Horizontal spacing from edges
        .padding(.top, 8) // Space above section
    }
}

struct CardStyle: ViewModifier { // Modifier that turns content into a card
    func body(content: Content) -> some View { // Defines how the modifier transforms content
        content
            .background(Color.theme.card) // Card background color
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) // Smooth rounded corners
    }
}
extension View { // Convenience to apply card style
    func cardStyle() -> some View { modifier(CardStyle()) } // Applies the CardStyle view modifier
}

// MARK: - Formatting Helpers
enum Formatting { // Namespace for formatting utilities
    static let currency: NumberFormatter = { // Shared number formatter instance
        let f = NumberFormatter() // Apple formatter class
        f.numberStyle = .currency // Currency style (e.g., €1.99)
        f.currencyCode = "EUR" // Force EUR; could be made dynamic
        f.locale = .current // Use device locale for separators/symbols
        return f // Return configured formatter
    }()
    static func priceText(_ value: Double) -> String { // Formats a price as text
        currency.string(from: NSNumber(value: value)) ?? "€ 0,00" // Fallback if formatting fails
    }
}

// MARK: - Measurement Enum & Picker
enum Measure: String, CaseIterable, Codable { // Supported measurement units
    case item, cup, bag, bunch, can, bottle, jar, carton, crate, box, net, pair, pack, sack, slice, piece, bar, tube, smallBag, g, kg, ml, l, cm, m // All unit cases

    var localizationKey: String { // Localization key for each unit
        switch self { // Switch over unit to choose localization key
        case .item: return "unit.item"
        case .cup: return "unit.cup"
        case .bag: return "unit.bag"
        case .bunch: return "unit.bunch"
        case .can: return "unit.can"
        case .bottle: return "unit.bottle"
        case .jar: return "unit.jar"
        case .carton: return "unit.carton"
        case .crate: return "unit.crate"
        case .box: return "unit.box"
        case .net: return "unit.net"
        case .pair: return "unit.pair"
        case .pack: return "unit.pack"
        case .sack: return "unit.sack"
        case .slice: return "unit.slice"
        case .piece: return "unit.piece"
        case .bar: return "unit.bar"
        case .tube: return "unit.tube"
        case .smallBag: return "unit.bagSmall"
        case .g: return "unit.g"
        case .kg: return "unit.kg"
        case .ml: return "unit.ml"
        case .l: return "unit.l"
        case .cm: return "unit.cm"
        case .m: return "unit.m"
        }
    }

    var localizedName: String { // Localized human-readable name for display
        let fallback: String // Fallback english-ish label
        switch self { // Determine fallback text based on unit
        case .g, .kg, .ml, .l, .cm, .m: fallback = rawValue // Use raw for metric
        case .smallBag: fallback = "Small Bag" // Custom capitalization
        default: fallback = String(describing: self).capitalized // Generic capitalization
        }
        let translated = NSLocalizedString(localizationKey, comment: "Measurement Unit") // Lookup localization
        return translated == localizationKey ? fallback : translated // Use fallback when missing
    }

    static func fromExternal(_ raw: String) -> Measure { // Normalizes free-form input to a known case
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() // Normalize spacing/case
        switch lower { // Map common synonyms
        case "piece", "item": return .piece
        case "cup": return .cup
        case "bag": return .bag
        case "bunch": return .bunch
        case "can": return .can
        case "bottle": return .bottle
        case "jar": return .jar
        case "carton": return .carton
        case "crate": return .crate
        case "box": return .box
        case "net": return .net
        case "pair": return .pair
        case "pack": return .pack
        case "sack": return .sack
        case "slice": return .slice
        case "bar": return .bar
        case "tube": return .tube
        case "smallbag", "bag_small": return .smallBag
        case "g": return .g
        case "kg": return .kg
        case "ml": return .ml
        case "l": return .l
        case "cm": return .cm
        case "m": return .m
        default: return Measure(rawValue: lower) ?? .piece // Fall back to piece
        }
    }
}

struct MeasurePicker: View { // UI control binding a String measure to enum selection
    @Binding var selection: String // External string binding (model uses String)
    var body: some View { // Declares UI
        Picker("Measure", selection: Binding( // Bridge between String and Measure
            get: { Measure.fromExternal(selection) }, // Convert string -> enum for picker
            set: { selection = $0.rawValue } // Convert enum -> string on change
        )) { // Start of the content builder
            ForEach(Measure.allCases, id: \.self) { m in // All supported units
                Text(m.localizedName).tag(m) // Localized label + tag
            }
        }
        .pickerStyle(.segmented) // Compact segmented style (beware many cases)
    }
}

// MARK: - Thumbnail
struct Thumbnail: View { // Square thumbnail with placeholder
    let image: UIImage? // Optional image to display
    var body: some View { // Declares UI content
        Group { // Conditional content
            if let img = image { // When image present
                Image(uiImage: img).resizable().scaledToFill() // Fill shape
            } else { // Placeholder state
                Image(systemName: "photo") // System photo placeholder
                    .imageScale(.large) // Large scale for visibility
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to fill available space
            }
        }
        .frame(width: 100, height: 100) // Fixed square
        .clipShape(RoundedRectangle(cornerRadius: 8)) // Rounded corners
        .overlay( // Subtle border
            RoundedRectangle(cornerRadius: 8) // Same rounded rectangle as clip for matching border
                .stroke(Color.gray.opacity(0.4), lineWidth: 1) // Light gray border stroke
        )
    }
}

// MARK: - Style Modifiers
struct RoundedCornerModifier: ViewModifier { // Adds corner radius to any view
    let radius: CGFloat // Radius value

    func body(content: Content) -> some View { // Applies modification to content
        content
            .cornerRadius(radius) // Apply standard cornerRadius
    }
}

struct ShadowModifier: ViewModifier { // Adds a shadow styling
    let color: Color // Shadow color
    let radius: CGFloat // Blur radius
    let x: CGFloat // X offset
    let y: CGFloat // Y offset

    func body(content: Content) -> some View { // Applies shadow to content
        content
            .shadow(color: color, radius: radius, x: x, y: y) // Apply shadow
    }
}

struct CapsuleBorderModifier: ViewModifier { // Draws a capsule border around content
    let color: Color // Border color
    let lineWidth: CGFloat // Border width

    func body(content: Content) -> some View { // Applies border overlay
        content
            .overlay( // Overlay places drawing above content
                Capsule().stroke(color, lineWidth: lineWidth) // Capsule outline
            )
    }
}

extension View { // Convenience wrappers
    func roundedCorners(_ radius: CGFloat) -> some View { // Rounded corner helper
        modifier(RoundedCornerModifier(radius: radius)) // Applies RoundedCornerModifier with given radius
    }

    func shadowStyle(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View { // Shadow helper
        modifier(ShadowModifier(color: color, radius: radius, x: x, y: y)) // Applies shadow with parameters
    }

    func capsuleBorder(color: Color, lineWidth: CGFloat) -> some View { // Capsule border helper
        modifier(CapsuleBorderModifier(color: color, lineWidth: lineWidth)) // Applies capsule border overlay
    }
}

#Preview { // Demonstrates key components using PreviewMocks context for consistency
    VStack(spacing: 16) { // Vertical stack to show components with spacing
        PrimaryButton(title: "Add to List") { } // Example primary button with empty action
        ProgressCard(title: "Progress", progress: 0.4, label: "4 / 10") // Progress card preview with sample values
        SectionHeader(title: "Checked Items") // Section header sample
        MeasurePicker(selection: .constant("piece")) // Picker bound to a constant selection
        Thumbnail(image: nil) // Thumbnail preview without image (placeholder shown)
    }
    .padding() // Adds padding around the preview stack
    .environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Provide preview view model context
}
