//  ItemExtraScreens.swift
//  MyListUI
//
//  Weitere Artikel-Screens:
//   • ManageItemsScreen   – Sheet „Artikel verwalten“ (Höhe 790) über der Liste
//   • BarcodeScanScreen   – Vollbild-Kamera mit Scan-Rahmen + Karte „Artikel erkannt“
//   • PriceHistoryScreen  – Sheet „Preisverlauf“ (Höhe 754) über „Artikel bearbeiten“
//
//  Screen-spezifische Tokens stehen in `ItemExtraTokens` (fileprivate), alles andere kommt aus `SheetTheme`.

import SwiftUI
import UIKit

// MARK: - Tokens (aus renderVals() der drei Quelldateien)

private struct ItemExtraTokens {
    let card: Paint
    let cardBorder: Color
    let cardShadow: [BoxShadow]
    let thumb: Paint
    let thumbShadow: [BoxShadow]
    let thumbIcon: Color
    let chipOnBg: Paint
    let chipOnText: Color
    let chipOffBg: Color
    let fade: [Gradient.Stop]
    let line: Color
    let menu: Color
    let menuBorder: Color
    let tile: Paint
    let ok: Color
    let okSoft: Color
    let dotFill: Color
    let areaFill: Color

    init(_ appearance: Appearance, accentHex: String? = nil) {
        let a = AccentScale(accentHex ?? appearance.defaultAccent, appearance)
        let w = { (alpha: Double) in Color.rgba(255, 255, 255, alpha) }

        if appearance == .dark {
            card = .linear(180, [stop(w(0.07), 0), stop(w(0.03), 1)])
            cardBorder = w(0.08)
            cardShadow = [.inner(0, 1, 0, 0, w(0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            thumb = .linear(150, [stop(a.base.color(0.22), 0), stop(a.base.color(0.06), 1)])
            thumbShadow = [.inner(0, 1, 0, 0, w(0.12))]
            thumbIcon = a.light.color()
            chipOnBg = .linear(180, [stop(a.light.color(), 0), stop(a.base.color(), 1)])
            chipOnText = .hex("#04262A")
            chipOffBg = w(0.05)
            fade = [stop(.rgba(10, 20, 22, 0), 0), stop(.hex("#0A1416"), 0.85)]
            line = w(0.08)
            menu = .rgba(20, 34, 37, 0.97)
            menuBorder = w(0.1)
            tile = .linear(150, [stop(a.base.color(0.24), 0), stop(a.base.color(0.06), 1)])
            ok = .hex("#4FD1A1")
            okSoft = .rgba(79, 209, 161, 0.14)
            dotFill = .hex("#0A1416")
            areaFill = a.base.color(0.16)
        } else {
            card = .color(.white)
            cardBorder = .hex("#EDF2F2")
            cardShadow = [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
            thumb = .linear(150, [stop(.hex("#F2F7F7"), 0), stop(.hex("#E4EEEF"), 1)])
            thumbShadow = [.inner(0, 1, 0, 0, .white)]
            thumbIcon = .hex("#7D9498")
            chipOnBg = .linear(180, [stop(a.base.color(), 0), stop(a.deep.color(), 1)])
            chipOnText = .white
            chipOffBg = .hex("#F4F7F7")
            fade = [stop(.rgba(255, 255, 255, 0), 0), stop(.white, 0.85)]
            line = .hex("#EDF1F2")
            menu = .rgba(255, 255, 255, 0.97)
            menuBorder = .rgba(15, 37, 40, 0.08)
            tile = .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)])
            ok = .hex("#1F8A5B")
            okSoft = .rgba(31, 138, 91, 0.1)
            dotFill = .white
            areaFill = a.base.color(0.12)
        }
    }
}

/// Icons, die nur hier vorkommen (Pfade exakt aus dem HTML).
private enum ItemExtraIcon {
    /// Blitz (Licht) – BarcodeScan
    static let bolt: [SVGElement] = [.path("M13 2 4 14h7l-1 8 9-12h-7z")]
    /// Wagen mit Rädern als Bogen-Pfade – BarcodeScan
    static let cartArcs: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7"),
                                         .path("M10.7 19a1.2 1.2 0 1 1-2.4 0 1.2 1.2 0 0 1 2.4 0zM17.7 19a1.2 1.2 0 1 1-2.4 0 1.2 1.2 0 0 1 2.4 0z")]
    /// Wagen ohne Räder – PriceHistory
    static let cartBody: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7")]
}

// MARK: - Artikel verwalten

struct ManagedItem: Identifiable, Hashable {
    let name: String
    let meta: String
    var id: String { name }
}

extension ManagedItem {
    static let samples: [ManagedItem] = [
        ManagedItem(name: "Bio Vollmilch-Schokolade", meta: "Fairglobe · 100 g"),
        ManagedItem(name: "Butter", meta: "Sonstiges · 1 Packung"),
        ManagedItem(name: "Kerrygold, original irische Butter aus Weidemilch", meta: "Kerrygold · 250 g"),
        ManagedItem(name: "Kokosmilch", meta: "Freshona · 400 ml"),
        ManagedItem(name: "Milch Mandel ohne Zucker", meta: "Lidl · 1 l"),
        ManagedItem(name: "Soyamilch", meta: "alpro · 1 l")
    ]
}

// Quelle: Design/html/ManageItems.dc.html (+ ManageItemsDark.dc.html)
//
//  Sheet 790, oben bündig bei y 54. Kopf: Innenabstand 10 / 20 → Griff 5 → 12 → Titelzeile 44 → 16 →
//  Suchfeld 50 → 12 → Filter-Chips 36 (Reihe beginnt bei x 30, siehe unten) → 18 →
//  Kopfzeile „6 Artikel“ → 10 → Karten 74 mit 10 Abstand. Unten Verlauf 120 zur Sheet-Farbe (85 %).
struct ManageItemsScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var items: [ManagedItem] = ManagedItem.samples
    var filters: [String] = ["Alle", "Milchprodukte", "Obst & Gemüse", "Backwaren", "Sonstiges"]
    var selectedFilter = "Alle"
    var onClose: () -> Void = {}
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelect: (ManagedItem) -> Void = { _ in }

    @State private var query = ""

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         items: [ManagedItem] = ManagedItem.samples,
         filters: [String] = ["Alle", "Milchprodukte", "Obst & Gemüse", "Backwaren", "Sonstiges"],
         selectedFilter: String = "Alle",
         onClose: @escaping () -> Void = {},
         onSelectFilter: @escaping (String) -> Void = { _ in },
         onSelect: @escaping (ManagedItem) -> Void = { _ in }) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.items = items
        self.filters = filters
        self.selectedFilter = selectedFilter
        self.onClose = onClose
        self.onSelectFilter = onSelectFilter
        self.onSelect = onSelect
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = ItemExtraTokens(appearance, accentHex: accentHex)

        return SheetScreen(appearance: appearance, accentHex: accentHex) {
            SheetSurface(k: k, height: 790) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            SheetHeader(title: "Artikel verwalten", k: k, onClose: onClose)
                            searchField(k)
                                .padding(.top, 16)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 20)

                        // Filter-Reihe: width 100 % + margin-right −20 in zentrierter Flex-Spalte
                        // → Randbox 330 zentriert → Reihe beginnt 10 pt weiter rechts (x 30), 350 breit, overflow hidden.
                        Color.clear
                            .frame(height: 36)
                            .overlay(alignment: .leading) {
                                HStack(spacing: 8) {
                                    ForEach(filters, id: \.self) { f in
                                        filterChip(f, on: f == selectedFilter, k: k, t: t)
                                    }
                                }
                                .fixedSize()
                            }
                            .clipped()
                            .padding(.leading, 30)
                            .padding(.trailing, 10)
                            .padding(.top, 12)

                        ScrollView {
                            VStack(spacing: 10) {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text("\(items.count) Artikel")
                                        .font(AppFont.dm(13, 600))
                                        .tracking(0.52)                       // 0.04em × 13
                                        .textCase(.uppercase)
                                        .foregroundStyle(k.sub)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text("Tippen = bearbeiten · wischen = löschen")
                                        .font(AppFont.dm(12, 400))
                                        .foregroundStyle(k.sub)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 4)

                                ForEach(items) { item in
                                    itemCard(item, k: k, t: t)
                                }
                            }
                            .padding(.top, 18)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)   // Platz unter dem Verlauf
                        }
                        .scrollIndicators(.hidden)
                    }

                    // Verlauf unten: 120 hoch, transparent → Sheet-Farbe bei 85 %
                    LinearGradient(stops: t.fade, startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// Suchfeld: Höhe 50, Pille, Rahmen 1, Innenabstand 16, Lupe 20 (sub), Text 15/400 in sub.
    private func searchField(_ k: SheetTheme) -> some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: k.sub, lineWidth: 2)
            // input::placeholder { color: inherit; opacity: 1 } → Platzhalter in sub
            TextField("", text: $query, prompt: Text("Gespeicherte Artikel durchsuchen").foregroundStyle(k.sub))
                .font(AppFont.dm(15, 400))
                .foregroundStyle(k.sub)
                .tint(k.accent)
                .accessibilityLabel("Gespeicherte Artikel durchsuchen")
        }
        .padding(.horizontal, 17)                                   // 1 border + 16 padding
        .frame(height: 50)
        .background(CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }

    /// Filter-Chip: Höhe 36 (border-box), Innenabstand 14, Rahmen 1, Text 14 (aktiv 600, sonst 500).
    /// Aktiv: Verlauf, Rahmen transparent (Verlauf reicht bis unter den Rahmen).
    private func filterChip(_ label: String, on: Bool, k: SheetTheme, t: ItemExtraTokens) -> some View {
        Button(action: { onSelectFilter(label) }) {
            Text(label)
                .font(AppFont.dm(14, on ? 600 : 500))
                .foregroundStyle(on ? t.chipOnText : k.text)
                .lineLimit(1)
                .padding(.horizontal, 15)                           // 1 border + 14 padding
                .frame(height: 36)
                .background(CSSBox(shape: Pill, paint: on ? t.chipOnBg : .color(t.chipOffBg),
                                   border: on ? 0 : 1, borderColor: k.fieldBorder))
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Artikel-Karte: Innenabstand 10 / 12 / 10 / 10 + Rahmen 1, Radius 22, Bild 52, Chevron 18 (schrumpfbar).
    private func itemCard(_ item: ManagedItem, k: SheetTheme, t: ItemExtraTokens) -> some View {
        Button(action: { onSelect(item) }) {
            HStack(spacing: 14) {
                SVGIcon(Icon.cameraOff, size: 22, color: t.thumbIcon, lineWidth: 1.7)
                    .frame(width: 52, height: 52)
                    .background(CSSBox(shape: RR(16), paint: t.thumb, shadows: t.thumbShadow))
                ManageItemsShrinkRow(gap: 14, trailingBasis: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(AppFont.outfit(16, 600))
                            .foregroundStyle(k.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(item.meta)
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    // SVG ohne flex-shrink: 0 → schrumpft mit (preserveAspectRatio meet, zentriert)
                    GeometryReader { g in
                        SVGIcon(Icon.chevronRight, size: min(g.size.width, g.size.height), color: k.sub, lineWidth: 2.2)
                            .frame(width: g.size.width, height: g.size.height)
                    }
                    .frame(height: 18)
                }
            }
            .padding(.leading, 11)                                  // 1 border + 10 padding
            .padding(.trailing, 13)                                 // 1 border + 12 padding
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
            .contentShape(RR(22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.meta)")
        .accessibilityHint("Bearbeiten")
    }
}

/// Flexbox-Nachbau für [Textspalte (flex-grow 1, min-width 0) · gap · SVG (flex-shrink 1, Basis 18)].
/// Passt der Text nicht, schrumpfen beide proportional zu ihrer Basisbreite – wie im Browser.
/// Dadurch wird der Chevron bei sehr langen Namen („Kerrygold, …“) sichtbar kleiner, exakt wie im Design.
private struct ManageItemsShrinkRow: Layout {
    var gap: CGFloat
    var trailingBasis: CGFloat

    private func widths(_ subviews: Subviews, available: CGFloat) -> (text: CGFloat, trailing: CGFloat) {
        let textBasis = subviews[0].sizeThatFits(.unspecified).width
        let free = max(0, available - gap)
        let sum = textBasis + trailingBasis
        if sum <= free || sum <= 0 {
            return (max(0, free - trailingBasis), trailingBasis)
        }
        let overflow = sum - free
        let trailing = max(0, trailingBasis - overflow * trailingBasis / sum)
        let text = max(0, textBasis - overflow * textBasis / sum)
        return (text, trailing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let ideal = subviews[0].sizeThatFits(.unspecified).width + gap + trailingBasis
        var available = proposal.width ?? ideal
        if !available.isFinite { available = ideal }
        let w = widths(subviews, available: available)
        let textHeight = subviews[0].sizeThatFits(ProposedViewSize(width: w.text, height: nil)).height
        return CGSize(width: available, height: max(textHeight, trailingBasis))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let w = widths(subviews, available: bounds.width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: w.text, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                          proposal: ProposedViewSize(width: w.trailing, height: trailingBasis))
    }
}

// MARK: - Barcode scannen

// Quelle: Design/html/BarcodeScan.dc.html (nur Light-Artboard vorhanden)
//
//  Vollbild ohne Sheet: Kamera-Hintergrund immer dunkel (radial-gradient 90 % 60 % at 50 % 40 %).
//  `appearance` steuert nur die Karte „Artikel erkannt“ (Dark-Tokens aus renderVals()).
//    62  Top-Bar: Glas-Knopf 48 · Titel-Pille · Glas-Knopf 48 (links/rechts 20)
//   220  Scan-Rahmen 280 × 180 (x 55): Ecken 38 (Rahmen 4, Radius 18), Scan-Linie y 88, Barcode 140 × 80 bei (70, 50)
//   330  „Kamerabild“ (Platzhalter, unter dem Rahmen gezeichnet)
//   420  Hinweis 15/500
//   Karte: links/rechts 12, unten 30, Innenabstand 16, Radius 30, Inhalt 14 auseinander
struct BarcodeScanScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var productName = "Kerrygold, original irische Butter"
    var productMeta = "Kerrygold · 250 g"
    var quantityText = "1×"
    /// Platzhalter-Schriftzug „Kamerabild“ – in der App `false`, dann liegt die Kameravorschau dahinter.
    var showsCameraPlaceholder = true
    var onClose: () -> Void = {}
    var onToggleLight: () -> Void = {}
    var onQuantity: () -> Void = {}
    var onAdd: () -> Void = {}
    var onContinue: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = ItemExtraTokens(appearance, accentHex: accentHex)

        return ZStack(alignment: .top) {
            // Kamera-Hintergrund
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])

            // Top-Bar
            HStack(spacing: 0) {
                glassButton(Icon.close, lineWidth: 2.2, label: "Schließen", action: onClose)
                Spacer(minLength: 0)
                Text("Barcode scannen")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                glassButton(ItemExtraIcon.bolt, lineWidth: 2, label: "Licht", action: onToggleLight)
            }
            .padding(.top, 62)
            .padding(.horizontal, 20)

            if showsCameraPlaceholder {
                Text("Kamerabild")
                    .font(AppFont.dm(12, 400))
                    .tracking(0.96)                                  // 0.08em × 12
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.25))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 330)
                    .accessibilityHidden(true)
            }

            BarcodeScanFrame(accent: k.accent)
                .frame(width: 280, height: 180)
                .padding(.top, 220)
                .accessibilityHidden(true)

            Text("Barcode in den Rahmen halten")
                .font(AppFont.dm(15, 500))
                .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 420)

            resultCard(k: k, t: t)
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    /// Glas-Knopf 48 (border-box): Rahmen 1 rgba(255,255,255,.28), Fläche rgba(255,255,255,.14), Icon 20 weiß.
    /// `backdrop-filter: blur(20px)` entfällt – der Kamera-Hintergrund ist hier ein weicher Verlauf.
    private func glassButton(_ icon: [SVGElement], lineWidth: CGFloat, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SVGIcon(icon, size: 20, color: .white, lineWidth: lineWidth)
                .frame(width: 48, height: 48)
                .background(CSSBox(shape: Circle(), paint: .color(.rgba(255, 255, 255, 0.14)),
                                   border: 1, borderColor: .rgba(255, 255, 255, 0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Karte „Artikel erkannt“: Innenabstand 16 + Rahmen 1, Radius 30, kein Schatten.
    private func resultCard(k: SheetTheme, t: ItemExtraTokens) -> some View {
        let nameFont = AppFont.ui(.outfit, 17, 600)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SVGIcon(Icon.check, size: 16, color: t.ok, lineWidth: 2.6)
                Text("Artikel erkannt")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.ok)
            }

            HStack(spacing: 14) {
                SVGIcon(ItemExtraIcon.cartArcs, size: 24, color: k.accentText, lineWidth: 1.8)
                    .frame(width: 56, height: 56)
                    .background(CSSBox(shape: RR(16), paint: t.tile))
                VStack(alignment: .leading, spacing: 3) {
                    Text(productName)
                        .font(AppFont.outfit(17, 600))
                        .foregroundStyle(k.text)
                        .cssLineHeight(21.25, font: nameFont)             // line-height 1.25
                        .fixedSize(horizontal: false, vertical: true)
                    Text(productMeta)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: onQuantity) {
                    Text(quantityText)
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(k.accentText)
                        .frame(width: 56, height: 56)
                        .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Menge: \(quantityText)")
                CTAButton(title: "Zur Liste hinzufügen", k: k, action: onAdd)
            }

            Button(action: onContinue) {
                Text("Weiter scannen")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.accentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(17)                                                   // 1 border + 16 padding
        .background(CSSBox(shape: RR(30), paint: .color(t.menu), border: 1, borderColor: t.menuBorder))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Erkannter Artikel")
    }
}

/// Scan-Rahmen 280 × 180: vier Ecken, Scan-Linie mit Glow, Barcode-Platzhalter (Reihenfolge wie im DOM).
private struct BarcodeScanFrame: View {
    let accent: Color

    /// `<rect x width>` des Barcode-SVG (y 0, Höhe 80)
    private static let bars: [(CGFloat, CGFloat)] = [
        (0, 4), (8, 2), (14, 6), (24, 2), (30, 4), (38, 2), (44, 6), (54, 2), (60, 4),
        (68, 2), (74, 6), (84, 4), (92, 2), (98, 6), (108, 2), (114, 4), (122, 2), (128, 6)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            corner.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            corner.scaleEffect(x: -1, y: 1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            corner.scaleEffect(x: 1, y: -1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            corner.scaleEffect(x: -1, y: -1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Scan-Linie: links/rechts 20, top 88, Höhe 3, Radius 2, box-shadow 0 0 16px accent
            Color.clear
                .frame(width: 240, height: 3)
                .background(CSSBox(shape: RR(2), paint: .color(accent), shadows: [.drop(0, 0, 16, 0, accent)]))
                .padding(.leading, 20)
                .padding(.top, 88)

            // Barcode: left 70, top 50, 140 × 80, fill rgba(255,255,255,.55)
            Path { p in
                for (x, w) in Self.bars {
                    p.addRect(CGRect(x: x, y: 0, width: w, height: 80))
                }
            }
            .fill(Color.rgba(255, 255, 255, 0.55))
            .frame(width: 140, height: 80)
            .padding(.leading, 70)
            .padding(.top, 50)
        }
        .frame(width: 280, height: 180)
    }

    /// Ecke oben links; content-box 34 + Rahmen 4 → Außenmaß 38.
    private var corner: some View {
        BarcodeScanCornerShape()
            .fill(accent, style: FillStyle(eoFill: true))
            .frame(width: 38, height: 38)
    }
}

/// `border-width: 4px 0 0 4px; border-top-left-radius: 18px` auf 34 × 34 (content-box):
/// Außenkante Radius 18, Innenkante Radius 18 − 4 = 14, gerade Enden (butt).
private struct BarcodeScanCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addPath(UnevenRoundedRectangle(topLeadingRadius: 18, style: .circular)
            .path(in: CGRect(x: rect.minX, y: rect.minY, width: 38, height: 38)))
        p.addPath(UnevenRoundedRectangle(topLeadingRadius: 14, style: .circular)
            .path(in: CGRect(x: rect.minX + 4, y: rect.minY + 4, width: 34, height: 34)))
        return p
    }
}

// MARK: - Preisverlauf

// Quelle: Design/html/PriceHistory.dc.html (+ PriceHistoryDark.dc.html)
//
//  Hintergrund: „Artikel bearbeiten“ (inkl. eigener Liste), weichgezeichnet 3 + Abdunkelung.
//  Sheet 754, unten bündig, Innenabstand 10 / 20 / 24:
//  Griff 5 → 12 → Titelzeile 44 → 16 → Produkt (Kachel 52) → 16 → 3 Kennzahlen (Abstand 8) → 16 →
//  Diagramm-Karte (Innenabstand 16/16/10, SVG 160 hoch) → 18 → „Nach Laden“ → 10 → Laden-Liste → 10 → Hinweis 12
struct PriceHistoryScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onClose: () -> Void = {}

    // static, damit der memberwise-Initializer nicht privat wird
    private static let stats: [(label: String, value: String)] = [
        ("Tiefster", "2,19 €"), ("Schnitt", "2,39 €"), ("Höchster", "2,59 €")
    ]
    private static let months = ["Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep"]

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = ItemExtraTokens(appearance, accentHex: accentHex)
        // Inline-SVG sitzt auf der Grundlinie → darunter bleibt die Unterlänge der Zeile (DM Sans 16, line-height normal).
        let svgDescent = abs(AppFont.ui(.dmSans, 16, 400).descender)

        return ZStack(alignment: .bottom) {
            EditItemScreen(appearance: appearance, accentHex: accentHex)
                .blur(radius: 3, opaque: true)
                .allowsHitTesting(false)
            k.scrim

            SheetSurface(k: k, height: 754) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Preisverlauf", k: k, onClose: onClose)

                    // Produkt
                    HStack(spacing: 14) {
                        SVGIcon(ItemExtraIcon.cartBody, size: 22, color: k.accentText, lineWidth: 1.8)
                            .frame(width: 52, height: 52)
                            .background(CSSBox(shape: RR(16), paint: t.tile))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kerrygold Butter")
                                .font(AppFont.outfit(17, 600))
                                .foregroundStyle(k.text)
                            Text("250 g · zuletzt 2,49 € bei Edeka")
                                .font(AppFont.dm(13, 400))
                                .foregroundStyle(k.sub)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 16)

                    // Kennzahlen: grid 3 × 1fr, gap 8
                    HStack(spacing: 8) {
                        ForEach(Self.stats.indices, id: \.self) { i in
                            let s = Self.stats[i]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.label)
                                    .font(AppFont.dm(12, 400))
                                    .foregroundStyle(k.sub)
                                Text(s.value)
                                    .font(AppFont.outfit(17, 600))
                                    .foregroundStyle(k.text)
                            }
                            .padding(.vertical, 11)                     // 1 border + 10 padding
                            .padding(.horizontal, 13)                   // 1 border + 12 padding
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, 16)

                    // Diagramm-Karte
                    VStack(spacing: 0) {
                        PriceHistoryChart(line: t.line, areaFill: t.areaFill, accent: k.accent, dotFill: t.dotFill)
                            .frame(height: 160)
                            .accessibilityLabel("Preisverlauf der letzten 7 Monate")
                        Color.clear.frame(height: svgDescent)
                        HStack(spacing: 0) {
                            ForEach(Array(Self.months.enumerated()), id: \.offset) { i, m in
                                if i > 0 { Spacer(minLength: 0) }
                                Text(m)
                                    .font(AppFont.dm(11, 400))
                                    .foregroundStyle(k.sub)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 17)                                  // 1 border + 16 padding
                    .padding(.horizontal, 17)
                    .padding(.bottom, 11)                               // 1 border + 10 padding
                    .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
                    .padding(.top, 16)

                    Text("Nach Laden")
                        .font(AppFont.dm(13, 600))
                        .tracking(0.52)                                 // 0.04em × 13
                        .textCase(.uppercase)
                        .foregroundStyle(k.sub)
                        .padding(.horizontal, 4)
                        .padding(.top, 18)

                    // Laden-Liste: Radius 20, Rahmen 1, Zeilen min. 56 (border-box), Trennlinie 1
                    VStack(spacing: 0) {
                        storeRow("Edeka", "zuletzt im September", price: "2,49 €", badge: nil, minHeight: 56, k: k, t: t)
                        Rectangle().fill(t.line).frame(height: 1)
                        storeRow("Lidl", "zuletzt im März", price: "2,19 €", badge: "GÜNSTIGSTER", minHeight: 55, k: k, t: t)
                    }
                    .padding(1)
                    .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder))
                    .clipShape(RR(20))
                    .padding(.top, 10)

                    Text("Beispielwerte · echte Preise kommen aus gescannten Kassenzetteln")
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    /// Laden-Zeile: Innenabstand 8 / 14, Abstand 12. Badge: 3 / 8, Pille, 11 pt.
    /// Hinweis: Das Design fordert DM Sans 700, lädt aber nur 400–600 → der Browser rendert 600.
    private func storeRow(_ name: String, _ detail: String, price: String, badge: String?, minHeight: CGFloat,
                          k: SheetTheme, t: ItemExtraTokens) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(k.text)
                Text(detail)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let badge {
                Text(badge)
                    .font(AppFont.dm(11, 600))
                    .foregroundStyle(t.ok)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule(style: .circular).fill(t.okSoft))
            }
            Text(price)
                .font(AppFont.outfit(16, 600))
                .foregroundStyle(k.text)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(minHeight: minHeight)
        .accessibilityElement(children: .combine)
    }
}

/// Diagramm exakt nach dem SVG: viewBox −6 −6 330 162, preserveAspectRatio="none".
/// Konturen werden im viewBox-Raum erzeugt und erst dann verzerrt – wie im Browser
/// (Strichstärken skalieren mit x 316/330 bzw. y 160/162).
private struct PriceHistoryChart: View {
    let line: Color
    let areaFill: Color
    let accent: Color
    let dotFill: Color

    /// Punkte in viewBox-Koordinaten (Mär … Sep)
    private static let points: [CGPoint] = [
        CGPoint(x: 0.0, y: 114.4), CGPoint(x: 53.0, y: 95.6), CGPoint(x: 106.0, y: 95.6),
        CGPoint(x: 159.0, y: 58.1), CGPoint(x: 212.0, y: 76.9), CGPoint(x: 265.0, y: 39.4),
        CGPoint(x: 318.0, y: 58.1)
    ]

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 330
            let sy = size.height / 162
            let tf = CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: 6 * sx, ty: 6 * sy)
            let pts = Self.points

            // Durchschnittslinie: M0 75 H318, 1 px, gestrichelt 4 4
            var avg = Path()
            avg.move(to: CGPoint(x: 0, y: 75))
            avg.addLine(to: CGPoint(x: 318, y: 75))
            ctx.fill(avg.strokedPath(StrokeStyle(lineWidth: 1, dash: [4, 4])).applying(tf), with: .color(line))

            // Fläche: Linie + L318 150 L0 150 Z
            var area = Path()
            area.move(to: pts[0])
            for p in pts.dropFirst() { area.addLine(to: p) }
            area.addLine(to: CGPoint(x: 318, y: 150))
            area.addLine(to: CGPoint(x: 0, y: 150))
            area.closeSubpath()
            ctx.fill(area.applying(tf), with: .color(areaFill))

            // Linie: 2,5, runde Enden/Ecken
            var polyline = Path()
            polyline.move(to: pts[0])
            for p in pts.dropFirst() { polyline.addLine(to: p) }
            ctx.fill(polyline.strokedPath(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)).applying(tf),
                     with: .color(accent))

            // Punkte: r 3,5 (Füllung dotFill), letzter r 5 (Füllung Akzent); Kontur jeweils 2 in Akzent
            for (i, p) in pts.enumerated() {
                let last = i == pts.count - 1
                let r: CGFloat = last ? 5 : 3.5
                let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(dot.applying(tf), with: .color(last ? accent : dotFill))
                ctx.fill(dot.strokedPath(StrokeStyle(lineWidth: 2)).applying(tf), with: .color(accent))
            }
        }
        .allowsHitTesting(false)
    }
}
