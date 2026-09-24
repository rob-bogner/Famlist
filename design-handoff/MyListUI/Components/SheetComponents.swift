//  SheetComponents.swift
//  MyListUI
//
//  Gemeinsame Bausteine aller Sheet-Screens.
//
//  WICHTIG: Die Sheets werden NICHT mit `.sheet()` präsentiert. Systemsheets haben
//  eigene Radien, Einzüge, Hintergründe und Abdunkelungen und würden vom Design abweichen.
//  Stattdessen liegt jedes Sheet als eigene Ebene über der (weichgezeichneten) Liste.

import SwiftUI

/// Liste im Hintergrund (Zustand .normal) + `backdrop-filter: blur(3px)` + Abdunkelung.
struct SheetScreen<Sheet: View>: View {
    let appearance: Appearance
    let accentHex: String?
    @ViewBuilder let sheet: () -> Sheet

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        ZStack(alignment: .bottom) {
            ListScreen(appearance: appearance, accentHex: accentHex, state: .normal)
                .blur(radius: 3, opaque: true)
                .allowsHitTesting(false)
            k.scrim
            sheet()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// Sheet-Fläche: obere Radien 34, Hintergrund, Schatten, 1-px-Oberkante (Dark), feste Höhe, unten bündig.
struct SheetSurface<Content: View>: View {
    let k: SheetTheme
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .circular)
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.top, 1)                      // border-top: 1px (Light: transparent, belegt aber Platz)
            .frame(height: height, alignment: .top)
            .overlay(alignment: .top) {
                if k.isDark {
                    ZStack(alignment: .top) {
                        // border-top: 1px rgba(255,255,255,.08)
                        TopBorderHairline(radius: 34, color: k.sheetTopBorder)
                        // box-shadow: inset 0 1px 0 rgba(255,255,255,.06) – liegt innerhalb des Rahmens (y 1…2)
                        TopBorderHairline(radius: 34, color: .rgba(255, 255, 255, 0.06))
                            .padding(.top, 1)
                    }
                }
            }
            .clipShape(shape)                    // overflow: hidden
            .background(CSSBox(shape: shape, paint: k.sheet, shadows: k.sheetShadow))
    }
}

/// Griff (40 × 5, Radius 3) + Titelzeile (Titel links, runder Schließen-Button rechts, 12 pt Abstand).
struct SheetHeader: View {
    let title: String
    let k: SheetTheme
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            RR(3)
                .fill(k.grabber)
                .frame(width: 40, height: 5)
            HStack(spacing: 0) {
                Text(title)
                    .font(AppFont.outfit(22, 600))
                    .tracking(-0.22)                 // -0.01em × 22
                    .foregroundStyle(k.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                CircleCloseButton(k: k, size: 44, iconSize: 18, lineWidth: 2.2, action: onClose)
                    .accessibilityLabel("Schließen")
            }
            .padding(.top, 12)
        }
    }
}

struct CircleCloseButton: View {
    let k: SheetTheme
    let size: CGFloat
    let iconSize: CGFloat
    let lineWidth: CGFloat
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            SVGIcon(Icon.close, size: iconSize, color: k.icon, lineWidth: lineWidth)
                .frame(width: size, height: size)
                .background(Circle().fill(k.close))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Primär-Button: Höhe 56, Pille, Glanz (links/rechts 24, oben 2, Höhe 22), Text 16/600.
struct CTAButton: View {
    let title: String
    let k: SheetTheme
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.dm(16, 600))
                .foregroundStyle(k.ctaText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(alignment: .top) {
                    GlossEllipse(opacity: 0.45)
                        .frame(height: 22)
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
                }
                .clipShape(Pill)
                .background(CSSBox(shape: Pill, paint: k.ctaPaint, shadows: k.ctaShadow))
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
    }
}

/// Feld-Beschriftung: 13/600, Farbe sub, 4 pt Einzug.
struct FieldLabel: View {
    let text: String
    let k: SheetTheme

    var body: some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .foregroundStyle(k.sub)
            .padding(.leading, 4)
    }
}

/// Fokussiertes Suchfeld (Höhe 54, Pille, Rahmen 1,5 in Akzent, 4-pt-Ring + Glow).
struct FocusedSearchField: View {
    let k: SheetTheme
    @Binding var text: String
    let placeholder: String
    let showsClear: Bool
    /// Statischer Design-Cursor (2 × 22, Radius 1, Akzent) + Text 2 pt dahinter
    /// (im Design: gap 12 + margin-left −10). Ohne ihn zeichnet iOS den Cursor (.tint).
    var showsDesignCursor = false

    var body: some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: k.accentText, lineWidth: 2)
            if showsDesignCursor {
                RR(1)
                    .fill(k.accent)
                    .frame(width: 2, height: 22)
                    .accessibilityHidden(true)
            }
            // Platzhalterfarbe = Browser-Standard aus dem Design: #757575.
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.hex("#757575")))
                .font(AppFont.dm(16, text.isEmpty ? 400 : 500))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .padding(.leading, showsDesignCursor ? -10 : 0)
                .accessibilityLabel("Artikel suchen")
            if showsClear {
                Button(action: { text = "" }) {
                    SVGIcon(Icon.close, size: 14, color: k.icon, lineWidth: 2.6)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(k.close))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche leeren")
            }
        }
        .padding(.leading, 17.5)                        // 1,5 border + 16 padding
        .padding(.trailing, showsClear ? 7.5 : 17.5)   // 1,5 border + 6 / 16 padding
        .frame(height: 54)
        .background(CSSBox(shape: Pill, paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                           shadows: [.drop(0, 0, 0, 4, k.ringSoft), .drop(0, 8, 20, -12, k.ringGlow)]))
    }
}

/// „Foto hinzufügen“-Kachel: 104 × 104, Radius 26, gestrichelter 1,5-pt-Rahmen.
struct PhotoAddTile: View {
    let k: SheetTheme
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                SVGIcon(Icon.camera, size: 26, color: k.accentText, lineWidth: 1.8)
                Text("Foto hinzufügen")
                    .font(AppFont.dm(12, 600))
                    .foregroundStyle(k.sub)
            }
            .frame(width: 104, height: 104)
            .background(CSSBox(shape: RR(26), paint: .color(k.field), border: 1.5, borderColor: k.dashed,
                               dash: [4.5, 4.5]))
            .contentShape(RR(26))
        }
        .buttonStyle(.plain)
    }
}

/// Mengen-Stepper: 148 × 52, Pille, − (deaktiviert bei 1) · Zahl · + (Glas-Knopf).
struct QuantityStepper: View {
    let k: SheetTheme
    @Binding var quantity: Int

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { if quantity > 1 { quantity -= 1 } }) {
                SVGIcon(Icon.minus, size: 16, color: quantity > 1 ? k.icon : k.stepOffIcon, lineWidth: 2.6)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(k.stepOff))
            }
            .buttonStyle(.plain)
            .disabled(quantity <= 1)
            .accessibilityLabel("Menge verringern")

            Spacer(minLength: 0)
            Text("\(quantity)")
                .font(AppFont.outfit(19, 600))
                .foregroundStyle(k.text)
            Spacer(minLength: 0)

            Button(action: { quantity += 1 }) {
                SVGIcon(Icon.plus, size: 16, color: .white, lineWidth: 2.6)
                    .frame(width: 40, height: 40)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.55)
                            .frame(height: 15)
                            .padding(.horizontal, 7)
                            .padding(.top, 2)
                    }
                    .clipShape(Circle())
                    .background(CSSBox(shape: Circle(), paint: k.stepPaint, shadows: k.stepShadow))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menge erhöhen")
        }
        .padding(.horizontal, 6)                        // 1 border + 5 padding
        .frame(width: 148, height: 52)
        .background(CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }
}

/// Maßeinheit-Auswahl: flexible Breite, Höhe 52, Radius 16, Doppel-Chevron rechts.
struct UnitPickerButton: View {
    let k: SheetTheme
    let value: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(value ?? "Maßeinheit")
                    .font(AppFont.dm(16, value == nil ? 400 : 500))
                    .foregroundStyle(value == nil ? k.sub : k.text)
                Spacer(minLength: 0)
                SVGIcon(Icon.chevronsUpDown, size: 16, color: k.sub, lineWidth: 2.2)
            }
            .padding(.leading, 17)     // 1 border + 16 padding
            .padding(.trailing, 15)    // 1 border + 14 padding
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Maßeinheit: \(value ?? "keine")")
    }
}

/// Kategorie-Chips: Höhe 42, Pille, Abstand 8, horizontal scrollbar bis zur Sheet-Kante.
struct CategoryChipRow: View {
    let k: SheetTheme
    var selected: String? = nil
    var onSelect: (String) -> Void = { _ in }

    private struct Category: Identifiable {
        let label: String
        let icon: [SVGElement]
        var id: String { label }
    }

    private let categories: [Category] = [
        Category(label: "Obst & Gemüse", icon: Icon.leaf),
        Category(label: "Milchprodukte", icon: Icon.drop),
        Category(label: "Backwaren", icon: Icon.cutlery)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { c in
                    Button(action: { onSelect(c.label) }) {
                        HStack(spacing: 8) {
                            SVGIcon(c.icon, size: 18, color: k.accentText, lineWidth: 1.9)
                            Text(c.label)
                                .font(AppFont.dm(15, 500))
                                .foregroundStyle(k.text)
                                .lineLimit(1)
                        }
                        .padding(.leading, 13)   // 1 border + 12 padding
                        .padding(.trailing, 17)  // 1 border + 16 padding
                        .frame(height: 42)
                        .background(CSSBox(shape: Pill, paint: .color(k.chip), border: 1, borderColor: k.fieldBorder))
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == c.label ? .isSelected : [])
                }
            }
        }
        .padding(.trailing, -20) // margin-right: -20px → läuft bis zur Sheet-Kante
        .frame(height: 42)
    }
}
