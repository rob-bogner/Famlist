// MARK: - ViewModifiers & UI Utilities

/*
 File: ViewModifiers.swift
 Project: GroceryGenius
 Created: 20.07.2025
 Last Updated: 17.08.2025

 Overview:
 Collection of small reusable SwiftUI building blocks (buttons, steppers, progress card, section header) plus formatting helpers, measurement enum & picker, lightweight thumbnail and style modifiers.

 Responsibilities / Includes:
 - PrimaryButton, QuantityStepper, ProgressCard, SectionHeader
 - CardStyle + convenience view modifier wrappers (roundedCorners, shadowStyle, capsuleBorder)
 - Formatting namespace (currency formatter + priceText)
 - Measure enum (localization + normalization) & MeasurePicker
 - Generic Thumbnail component

 Design Notes:
 - Keep visual tokens (spacing, radii) external (DesignSystem) except minimal inline values
 - Measure stored as raw String in model for backward compatibility; enum normalizes user input
 - Formatting isolated to enable future NumberFormatter reuse / caching

 Possible Enhancements:
 - Add accessibility variants for larger content size categories
 - Provide async image loading variant for remote thumbnails
 - Migrate measure persistence to strongly typed enum in model (breaking change)
*/

import SwiftUI

// MARK: - Reusable UI Components
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }
}

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

// MARK: - Formatting Helpers
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

// MARK: - Measurement Enum & Picker
enum Measure: String, CaseIterable, Codable {
    case item, cup, bag, bunch, can, bottle, jar, carton, crate, box, net, pair, pack, sack, slice, piece, bar, tube, smallBag, g, kg, ml, l, cm, m

    var localizationKey: String {
        switch self {
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

    var localizedName: String {
        let fallback: String
        switch self {
        case .g, .kg, .ml, .l, .cm, .m: fallback = rawValue
        case .smallBag: fallback = "Small Bag"
        default: fallback = String(describing: self).capitalized
        }
        let translated = NSLocalizedString(localizationKey, comment: "Measurement Unit")
        return translated == localizationKey ? fallback : translated
    }

    static func fromExternal(_ raw: String) -> Measure {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
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
        default: return Measure(rawValue: lower) ?? .piece
        }
    }
}

struct MeasurePicker: View {
    @Binding var selection: String
    var body: some View {
        Picker("Measure", selection: Binding(
            get: { Measure.fromExternal(selection) },
            set: { selection = $0.rawValue }
        )) {
            ForEach(Measure.allCases, id: \.self) { m in
                Text(m.localizedName).tag(m)
            }
        }
        .pickerStyle(.segmented) // Note: may be unsuitable with many entries
    }
}

// MARK: - Thumbnail
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

// MARK: - Style Modifiers
struct RoundedCornerModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .cornerRadius(radius)
    }
}

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

extension View {
    func roundedCorners(_ radius: CGFloat) -> some View {
        modifier(RoundedCornerModifier(radius: radius))
    }

    func shadowStyle(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        modifier(ShadowModifier(color: color, radius: radius, x: x, y: y))
    }

    func capsuleBorder(color: Color, lineWidth: CGFloat) -> some View {
        modifier(CapsuleBorderModifier(color: color, lineWidth: lineWidth))
    }
}

#if DEBUG
#Preview("PrimaryButton") {
    PrimaryButton(title: "Add") {}
        .padding()
}
private struct QuantityStepperPreviewHost: View {
    @State var value: Int = 2
    var body: some View { QuantityStepper(value: $value, range: 0...9).padding() }
}
#Preview("QuantityStepper") { QuantityStepperPreviewHost() }
#Preview("ProgressCard") {
    ProgressCard(title: "Progress", progress: 0.4, label: "2 / 5")
        .padding()
        .background(Color.theme.background)
}
#Preview("SectionHeader") { SectionHeader(title: "Checked Items").padding().background(Color.theme.background) }
private struct MeasurePickerPreviewHost: View {
    @State var selection: String = "l"
    var body: some View { MeasurePicker(selection: $selection).padding() }
}
#Preview("MeasurePicker") { MeasurePickerPreviewHost() }
#Preview("Thumbnail – empty") { Thumbnail(image: nil).padding() }
#endif
