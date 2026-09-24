/*
 ListDock.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dock am unteren Rand: dunkle Pille 68 hoch (aktive „Liste“-Pille 52, drei Nav-Icons mit 48er
   Trefferfläche) + Glas-FAB 68 mit 12 pt Abstand. Ersetzt FloatingBottomMenuBar.

 🔰 Notes for Beginners:
 - Sortieren ist ein System-Menü (Kategorie / Alphabetisch / Datum), der aktive Eintrag trägt einen Haken.
 - Duplizieren und „Erledigte löschen“ fragen vorher nach; die Dialoge liegen in ShoppingListView.
 - `liveBlur` legt `.ultraThinMaterial` hinter die Pille (`backdrop-filter`, README Grenze 3).
   ShoppingListView schaltet ihn nur im Dark Mode ein: Dort ist die Pille nur zu 78 % deckend und
   scrollende Karten würden sonst sichtbar durchscheinen. Die Light-Pille ist voll deckend.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an echte Aktionen angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Bottom dock with list pill, sort menu, duplicate, delete-checked and the add FAB.
struct ListDock: View {
    let t: ListTheme
    let sortOrder: SortOrder
    let hasCheckedItems: Bool
    var liveBlur = false
    var onSort: (SortOrder) -> Void = { _ in }
    var onDuplicate: () -> Void = {}
    var onDeleteChecked: () -> Void = {}
    var onAdd: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            pill
            fab
        }
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: 0) {
            activeListPill
            Spacer(minLength: 0)
            sortMenu
            Spacer(minLength: 0)
            navButton(Icon.duplicate, "Liste duplizieren", action: onDuplicate)
            Spacer(minLength: 0)
            navButton(Icon.trash, "Erledigte löschen", action: onDeleteChecked)
                .disabled(!hasCheckedItems)
                .opacity(hasCheckedItems ? 1 : 0.4)
        }
        .padding(.leading, 8)    // 1 border + 7 padding
        .padding(.trailing, 9)   // 1 border + 8 padding
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(alignment: .top) {
            // Glanz: left/right 24, top 0 (ab Padding-Box → +1), Höhe 26, untere Radien 26
            UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .circular)
                .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, 0.14), 0), stop(.rgba(255, 255, 255, 0), 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 26)
                .padding(.horizontal, 25)
                .padding(.top, 1)
                .allowsHitTesting(false)
        }
        .clipShape(Pill)
        .background {
            if liveBlur { Pill.fill(.ultraThinMaterial) }
        }
        .background(CSSBox(shape: Pill, paint: .color(t.nav), border: 1, borderColor: t.navBorder, shadows: t.navShadow))
    }

    private var activeListPill: some View {
        HStack(spacing: 8) {
            SVGIcon(Icon.listCheck, size: 20, color: t.navActiveText, lineWidth: 2)
            Text("Liste")
                .font(AppFont.dm(15, 600))
                .foregroundStyle(t.navActiveText)
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .frame(height: 52)
        .background(CSSBox(shape: Pill, paint: t.navActive, shadows: t.navActiveShadow))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits([.isSelected, .isHeader])
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    onSort(order)
                } label: {
                    if order == sortOrder {
                        Label(label(for: order), systemImage: "checkmark")
                    } else {
                        Text(label(for: order))
                    }
                }
            }
        } label: {
            navIcon(Icon.sort)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Sortieren, aktuell \(label(for: sortOrder))")
    }

    private func label(for order: SortOrder) -> String {
        switch order {
        case .category: return "Nach Kategorie"
        case .alphabetical: return "Alphabetisch"
        case .dateAdded: return "Nach Datum"
        }
    }

    private func navButton(_ icon: [SVGElement], _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { navIcon(icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    private func navIcon(_ icon: [SVGElement]) -> some View {
        SVGIcon(icon, size: 22, color: t.navIcon, lineWidth: 1.9)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onAdd()
        }) {
            SVGIcon(Icon.plus, size: 28, color: .white, lineWidth: 2.6)
                .shadow(color: .rgba(0, 40, 45, 0.35), radius: 1.5, x: 0, y: 2) // drop-shadow(0 2px 3px)
                .frame(width: 68, height: 68)
                .background { fabGloss }
                .clipShape(Circle())
                .background(CSSBox(shape: Circle(), paint: t.fabBg, shadows: t.fabShadow))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Artikel hinzufügen")
    }

    private var fabGloss: some View {
        ZStack {
            GlossEllipse(opacity: 0.6)
                .frame(height: 26)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .frame(maxHeight: .infinity, alignment: .top)
            Ellipse()
                .fill(Color.rgba(255, 255, 255, 0.22))
                .frame(height: 9)
                .blur(radius: 3)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 30) {
        ListDock(t: ListTheme(.light), sortOrder: .category, hasCheckedItems: true)
        ListDock(t: ListTheme(.dark), sortOrder: .alphabetical, hasCheckedItems: false)
            .padding(12)
            .background(Color.hex("#071012"))
    }
    .padding(20)
}
