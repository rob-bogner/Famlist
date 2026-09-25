//  CategoryScreens.swift
//  MyListUI
//
//  „Kategorien verwalten“ (Sheet 790 über der Liste) und
//  „Kategorie bearbeiten“ (Sheet 594 über „Kategorien verwalten“).
//  Gemeinsame EKK-Bausteine: siehe OnboardingScreens.swift.

import SwiftUI

// MARK: - Daten

struct EKKCategory: Identifiable, Hashable {
    let name: String
    let subtitle: String
    let icon: [SVGElement]
    var id: String { name }

    static func == (l: EKKCategory, r: EKKCategory) -> Bool { l.name == r.name }
    func hash(into h: inout Hasher) { h.combine(name) }
}

extension EKKCategory {
    static let samples: [EKKCategory] = [
        EKKCategory(name: "Obst & Gemüse", subtitle: "Tippen zum Bearbeiten", icon: Icon.leaf),
        EKKCategory(name: "Milchprodukte", subtitle: "Tippen zum Bearbeiten", icon: Icon.drop),
        EKKCategory(name: "Backwaren", subtitle: "Tippen zum Bearbeiten", icon: Icon.cutlery),
        EKKCategory(name: "Sonstiges", subtitle: "Standard · kann nicht gelöscht werden", icon: EKKIcon.tag)
    ]

    /// Icon-Auswahl in „Kategorie bearbeiten“ (Reihenfolge wie im Design, 5 × 2).
    static let iconChoices: [[SVGElement]] = [
        Icon.leaf, Icon.drop, Icon.cutlery, EKKIcon.tag, EKKIcon.bag,
        EKKIcon.dropSmall, EKKIcon.bowl, EKKIcon.fruit, EKKIcon.umbrella, EKKIcon.cup
    ]
}

// MARK: - Flex-Zeile (CSS flex-grow / flex-shrink)

/// Waagerechte Zeile mit exakter CSS-Flexbox-Verteilung:
/// Basis = ideale Breite; Überschuss nach flex-grow, Mangel nach flex-shrink × Basis.
/// Nötig für „Sonstiges“: dort ist der Untertitel breiter als der Platz, und im Browser
/// schrumpfen Nummer (22) und Griff-Button (44) anteilig mit.
struct EKKFlexRow: Layout {
    var spacing: CGFloat
    var grow: [CGFloat]
    var shrink: [CGFloat]

    private func widths(total: CGFloat, subviews: Subviews) -> [CGFloat] {
        let n = subviews.count
        let basis = subviews.map { $0.sizeThatFits(.unspecified).width }
        let free = total - basis.reduce(0, +) - spacing * CGFloat(max(0, n - 1))
        var result = basis
        if free > 0 {
            let g = (0..<n).map { $0 < grow.count ? grow[$0] : 0 }
            let sum = g.reduce(0, +)
            if sum > 0 {
                for i in 0..<n { result[i] += free * g[i] / sum }
            }
        } else if free < 0 {
            let f = (0..<n).map { ($0 < shrink.count ? shrink[$0] : 1) * basis[$0] }
            let sum = f.reduce(0, +)
            if sum > 0 {
                for i in 0..<n { result[i] = max(0, basis[i] + free * f[i] / sum) }
            }
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +)
            + spacing * CGFloat(max(0, subviews.count - 1))
        let total: CGFloat
        if let w = proposal.width, w.isFinite { total = w } else { total = natural }
        let ws = widths(total: total, subviews: subviews)
        var height: CGFloat = 0
        for (i, s) in subviews.enumerated() {
            height = max(height, s.sizeThatFits(ProposedViewSize(width: ws[i], height: nil)).height)
        }
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ws = widths(total: bounds.width, subviews: subviews)
        var x = bounds.minX
        for (i, s) in subviews.enumerated() {
            s.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                    proposal: ProposedViewSize(width: ws[i], height: nil))
            x += ws[i] + spacing
        }
    }
}

// MARK: - Kategorien verwalten
//
// Quelle: Design/html/ManageCategories.dc.html (Dark: ManageCategoriesDark.dc.html)
//  Sheet 790, Innenabstand 10/20/34. Titelzeile → 16 → Hinweis-Box (Padding 12/14, Radius 16) →
//  20 → „4 Kategorien“ → 10 → Zeilen 68 (Abstand 8, Radius 20, Padding 0/10/0/12, Abstand 12) →
//  12 → „Neue Kategorie“ 56 (Radius 20, gestrichelt 1,5)

struct ManageCategoriesScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var categories: [EKKCategory] = EKKCategory.samples
    var onClose: () -> Void = {}
    var onEdit: (EKKCategory) -> Void = { _ in }
    var onAdd: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)
        let hintFont = AppFont.ui(.dmSans, 13, 400)

        return EKKSheetStage(k: k, background: {
            ListScreen(appearance: appearance, accentHex: accentHex, state: .normal)
        }) {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kategorien verwalten", k: k, onClose: onClose)

                    // Hinweis: Rahmen 1 (content-box) → Einzug 13 / 15
                    HStack(alignment: .top, spacing: 10) {
                        SVGIcon(EKKIcon.map, size: 20, color: k.accentText, lineWidth: 1.9)
                            .padding(.top, 1)
                            .accessibilityHidden(true)
                        Text("Sortiere die Kategorien so, wie du durch deinen Laden gehst. Die Liste zeigt die Artikel dann in dieser Reihenfolge.")
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(k.sub)
                            .cssLineHeight(18.85, font: hintFont)          // line-height 1.45
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 15)
                    .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                    .padding(.top, 16)

                    EKKSectionLabel(text: "\(categories.count) Kategorien", k: k)
                        .padding(.top, 20)

                    VStack(spacing: 8) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, c in
                            categoryRow(index: index, c, k: k, t: t)
                        }
                    }
                    .padding(.top, 10)

                    Button(action: onAdd) {
                        HStack(spacing: 8) {
                            SVGIcon(Icon.plus, size: 18, color: k.accentText, lineWidth: 2.4)
                            Text("Neue Kategorie")
                                .font(AppFont.dm(15, 600))
                                .foregroundStyle(k.accentText)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(CSSBox(shape: RR(20), border: 1.5, borderColor: k.dashed, dash: [4.5, 4.5]))
                        .contentShape(RR(20))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// Zeile 68 (border-box): Nummer 22 · Kachel 44 · Name/Untertitel (grow) · Griff 44, Abstand 12.
    private func categoryRow(index: Int, _ c: EKKCategory, k: SheetTheme, t: EKKTokens) -> some View {
        EKKFlexRow(spacing: 12, grow: [0, 0, 1, 0], shrink: [1, 0, 1, 1]) {
            Text("\(index + 1)")
                .font(AppFont.outfit(15, 600))
                .foregroundStyle(k.sub)
                .frame(minWidth: 0, idealWidth: 22, maxWidth: 22)
                .accessibilityHidden(true)

            SVGIcon(c.icon, size: 22, color: k.accentText, lineWidth: 1.9)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: RR(14), paint: t.tile, shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.4))]))
                .accessibilityHidden(true)

            Button(action: { onEdit(c) }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name)
                        .font(AppFont.outfit(16, 600))
                        .foregroundStyle(k.text)
                    Text(c.subtitle)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                SVGIcon(EKKIcon.grip, size: 20, color: k.sub, lineWidth: 3)
                    .frame(minWidth: 0, idealWidth: 44, maxWidth: 44)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(c.name) verschieben")
        }
        .padding(.leading, 13)                                   // 1 Rahmen + 12 Padding
        .padding(.trailing, 11)                                  // 1 Rahmen + 10 Padding
        .frame(height: 68)
        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    }
}

// MARK: - Kategorie bearbeiten
//
// Quelle: Design/html/EditCategory.dc.html (Dark: EditCategoryDark.dc.html)
//  Hintergrund: „Kategorien verwalten“ (weichgezeichnet + Abdunkelung). Sheet 594, Innenabstand 10/20/34.
//  Titelzeile → 20 → [Kachel 64 · 14 · Name-Label · 6 · Feld 52 (fokussiert)] → 20 →
//  „Icon“ · 8 · Raster 5 Spalten × 56 (Abstand 8) → auto (min. 20) → CTA · 8 · „Kategorie löschen“ 48 · 4 · Hinweis 12

struct EditCategoryScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var initialName = "Milchprodukte"
    var initialIcon = 1
    var onClose: () -> Void = {}
    var onSave: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var name: String? = nil
    @State private var selectedIcon: Int? = nil

    // Expliziter Initializer: `@State private` würde den memberwise-Initializer privat machen.
    init(appearance: Appearance = .light,
         accentHex: String? = nil,
         initialName: String = "Milchprodukte",
         initialIcon: Int = 1,
         onClose: @escaping () -> Void = {},
         onSave: @escaping () -> Void = {},
         onDelete: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.initialName = initialName
        self.initialIcon = initialIcon
        self.onClose = onClose
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)
        let nameBinding = Binding<String>(get: { name ?? initialName }, set: { name = $0 })
        let selected = selectedIcon ?? initialIcon
        let choices = EKKCategory.iconChoices
        let tileIcon = choices.indices.contains(selected) ? choices[selected] : Icon.drop

        return EKKSheetStage(k: k, background: {
            ManageCategoriesScreen(appearance: appearance, accentHex: accentHex)
        }) {
            SheetSurface(k: k, height: 594) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kategorie bearbeiten", k: k, onClose: onClose)

                    HStack(spacing: 14) {
                        SVGIcon(tileIcon, size: 30, color: .white, lineWidth: 1.9)
                            .frame(width: 64, height: 64)
                            .background(CSSBox(shape: RR(20), paint: t.avatarBg,
                                               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.4))]))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Name", k: k)
                            TextField("", text: nameBinding)
                                .font(AppFont.dm(16, 500))
                                .foregroundStyle(k.text)
                                .tint(k.accent)
                                .padding(.horizontal, 17.5)                 // 1,5 Rahmen + 16 Padding
                                .frame(height: 52)
                                .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5,
                                                   borderColor: k.ring, shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
                                .accessibilityLabel("Name der Kategorie")
                        }
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Icon", k: k)
                        VStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { row in
                                HStack(spacing: 8) {
                                    ForEach(0..<5, id: \.self) { col in
                                        iconCell(row * 5 + col, icon: choices[row * 5 + col], selected: selected, k: k)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        CTAButton(title: "Speichern", k: k, action: onSave)
                        EKKTextButton(title: "Kategorie löschen", color: t.danger, action: onDelete)
                        Text("Artikel dieser Kategorie wandern nach „Sonstiges“.")
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, -4)                              // margin-top: −4
                    }
                    .padding(.top, 20)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// Icon-Taste: Höhe 56, Radius 16; normal Rahmen 1 fieldBorder auf field, gewählt Rahmen 2 ring auf ringSoft.
    private func iconCell(_ index: Int, icon: [SVGElement], selected: Int, k: SheetTheme) -> some View {
        let isOn = index == selected
        return Button(action: { selectedIcon = index }) {
            SVGIcon(icon, size: 24, color: k.accentText, lineWidth: 1.9)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(CSSBox(shape: RR(16), paint: .color(isOn ? k.ringSoft : k.field),
                                   border: isOn ? 2 : 1, borderColor: isOn ? k.ring : k.fieldBorder))
                .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Icon \(index + 1)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
