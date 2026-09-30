/*
 ProductDetailCategoryPopover.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kategorie-Auswahl „Glas-Popover“ (Prototyp PickM): eigenes Menü unter der Kategorie-Karte statt
   System-Menü. Suchfeld, Kategorien mit Symbol und Haken, unten „Neue Kategorie“.

 🔰 Notes for Beginners:
 - Breite 260, Innenabstand 6, Radius 20, Fläche menu (fast deckend) mit großem weichem Schatten.
 - Zeilen 44 hoch, Symbol-Kachel 28 (Radius 9, Akzent-Tönung), gewählt = getönte Fläche + Haken.
 - Höchstens 7 Zeilen sichtbar, der Rest scrollt. Suchen filtert sofort; gibt es den Namen noch nicht,
   heißt die letzte Zeile „„Name“ anlegen“ und legt die Kategorie an (Symbol-Vorschlag aus dem Namen).
 - Position und Schließen (Tippen daneben) regelt ProductDetailSheet über einen Anker.

 📝 Last Change:
 - Initial creation (Test vor Übernahme in die User Journey, Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Eigenes Glas-Menü für die Kategorie.
struct ProductDetailCategoryPopover: View {
    let k: SheetTheme
    let categories: [CategoryDefinition]
    let selection: String
    let onSelect: (String) -> Void
    let onCreate: (String) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    static let width: CGFloat = 260
    private static let rowHeight: CGFloat = 44
    private static let maxRows = 7

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }
    private var filtered: [CategoryDefinition] {
        trimmed.isEmpty ? categories : categories.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
    private var canCreateTyped: Bool {
        !trimmed.isEmpty && !categories.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    private var menuPaint: Color { k.isDark ? .rgba(20, 34, 37, 0.97) : .rgba(255, 255, 255, 0.97) }
    private var menuBorder: Color { k.isDark ? .rgba(255, 255, 255, 0.1) : .rgba(15, 37, 40, 0.08) }
    private var menuShadow: [BoxShadow] {
        k.isDark ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 24, 48, -16, .rgba(0, 0, 0, 0.8))]
                 : [.drop(0, 24, 48, -16, .rgba(12, 40, 44, 0.35))]
    }
    private var highlight: Color { k.a.base.color(k.isDark ? 0.18 : 0.1) }
    private var line: Color { k.isDark ? .rgba(255, 255, 255, 0.08) : .hex("#EDF1F2") }

    var body: some View {
        VStack(spacing: 0) {
            searchField.padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered) { row($0) }
                    if filtered.isEmpty && !canCreateTyped {
                        Text("Keine Treffer")
                            .font(AppFont.dm(14, 500))
                            .foregroundStyle(k.sub)
                            .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: Self.rowHeight * CGFloat(min(max(filtered.count, filtered.isEmpty && !canCreateTyped ? 1 : 0), Self.maxRows)))

            Rectangle().fill(line).frame(height: 1).padding(.vertical, 4).padding(.horizontal, 6)

            if !selection.isEmpty && trimmed.isEmpty {
                actionRow(icon: Icon.close, title: "Ohne Kategorie", color: k.sub) { pick("") }
            }
            actionRow(icon: Icon.plus, title: canCreateTyped ? "„\(trimmed)“ anlegen" : "Neue Kategorie",
                      color: k.accentText) {
                if canCreateTyped { create(trimmed) } else { searchFocused = true }
            }
        }
        .padding(6)
        .frame(width: Self.width)
        .background(CSSBox(shape: RR(20), paint: .color(menuPaint), border: 1, borderColor: menuBorder, shadows: menuShadow))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kategorie wählen")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            SVGIcon(Icon.search, size: 15, color: k.sub, lineWidth: 2)
            TextField("", text: $query, prompt: Text(searchFocused ? "Name eingeben" : "Suchen").foregroundStyle(k.sub))
                .font(AppFont.dm(14, 400))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .focused($searchFocused)
                .submitLabel(.done)
                .onSubmit { if canCreateTyped { create(trimmed) } else if let first = filtered.first { pick(first.name) } }
                .accessibilityLabel("Kategorie suchen")
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(RR(12).fill(k.field))
    }

    private func row(_ category: CategoryDefinition) -> some View {
        let isOn = category.name == selection
        return Button { pick(category.name) } label: {
            HStack(spacing: 10) {
                SVGIcon(category.svgIcon, size: 15, color: k.accentText, lineWidth: 2)
                    .frame(width: 28, height: 28)
                    .background(RR(9).fill(k.a.base.color(k.isDark ? 0.2 : 0.12)))
                Text(category.name)
                    .font(AppFont.dm(15, isOn ? 600 : 500))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isOn { SVGIcon(Icon.check, size: 16, color: k.accentText, lineWidth: 2.6) }
            }
            .padding(.horizontal, 10)
            .frame(height: Self.rowHeight)
            .background(RR(12).fill(isOn ? highlight : .clear))
            .contentShape(RR(12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func actionRow(icon: [SVGElement], title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SVGIcon(icon, size: 16, color: color, lineWidth: 2.2)
                    .frame(width: 28)
                Text(title)
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(color)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ name: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        onSelect(name)
    }

    private func create(_ name: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onCreate(name)
    }
}

/// Anker der Kategorie-Karte, damit das Popover im Sheet darüber liegen kann.
struct CategoryCardAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

#Preview {
    ProductDetailCategoryPopover(k: SheetTheme(.light), categories: CategoryDefinition.defaults,
                                 selection: CategoryDefinition.defaults.first?.name ?? "", onSelect: { _ in }, onCreate: { _ in })
        .padding(20)
}

#Preview("Dark") {
    ProductDetailCategoryPopover(k: SheetTheme(.dark), categories: CategoryDefinition.defaults,
                                 selection: "", onSelect: { _ in }, onCreate: { _ in })
        .padding(20)
        .background(Color.hex("#0A1416"))
}
