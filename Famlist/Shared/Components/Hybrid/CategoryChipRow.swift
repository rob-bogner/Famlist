/*
 CategoryChipRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kategorie-Chips der Hybrid-Sheets: Höhe 42, Pille, Abstand 8, horizontal scrollbar bis zur Sheet-Kante.

 🔰 Notes for Beginners:
 - Zeigt alle ItemCategory-Werte in Supermarkt-Reihenfolge (das Design zeigt nur drei Beispiele).
 - Gewählter Chip: Rahmen 1,5 in Akzent + Akzent-Tönung. Das Design zeigt keinen gewählten Zustand;
   die Werte folgen dem fokussierten Feld (ring / ringSoft).
 - Erneutes Tippen auf den gewählten Chip hebt die Auswahl auf (wie bisher im CategoryPickerRow).

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen, an echte Kategorien und Auswahl angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Kategorie-Chips: Höhe 42, Pille, Abstand 8, horizontal scrollbar bis zur Sheet-Kante.
struct CategoryChipRow: View {
    let k: SheetTheme
    /// Rohwert der Kategorie wie im ItemFormViewModel ("" = keine Auswahl).
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ItemCategory.displayOrder) { category in
                    chip(for: category)
                }
            }
            .padding(.vertical, 5)       // Platz für den 4-pt-Ring des gewählten Chips
            .padding(.trailing, 20)      // letzter Chip endet mit Sheet-Innenabstand
        }
        .padding(.trailing, -20) // margin-right: -20px → läuft bis zur Sheet-Kante
        .padding(.vertical, -5)
        .frame(height: 42)
    }

    private func chip(for category: ItemCategory) -> some View {
        let isSelected = selection == category.rawValue
        return Button(action: { toggle(category) }) {
            HStack(spacing: 8) {
                SVGIcon(category.svgIcon, size: 18, color: k.accentText, lineWidth: 1.9)
                Text(category.rawValue)
                    .font(AppFont.dm(15, isSelected ? 600 : 500))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
            }
            .padding(.leading, 13)   // 1 border + 12 padding
            .padding(.trailing, 17)  // 1 border + 16 padding
            .frame(height: 42)
            .background(CSSBox(shape: Pill,
                               paint: .color(isSelected ? k.ringSoft : k.chip),
                               border: isSelected ? 1.5 : 1,
                               borderColor: isSelected ? k.ring : k.fieldBorder))
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kategorie \(category.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ category: ItemCategory) {
        if selection == category.rawValue {
            selection = ""
        } else {
            selection = category.rawValue
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

#Preview {
    @Previewable @State var selection = "Milchprodukte"
    CategoryChipRow(k: SheetTheme(.light), selection: $selection)
        .padding(20)
}
