/*
 CategoryPickerRow.swift

 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Horizontaler, scrollbarer Chip-Picker zur Kategorieauswahl in
   AddItemView und EditItemView.

 🛠 Includes:
 - Einzelne CategoryChip-Komponente (Pill-Design)
 - Haptisches Feedback bei Auswahl
 - Auswahl aufhebbar durch erneutes Tippen

 📝 Last Change:
 - Initial creation (FAM-63)
 ------------------------------------------------------------------------
*/

import SwiftUI

/// Einzelner auswählbarer Kategorie-Chip.
private struct CategoryChip: View {
    let category: ItemCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel("Kategorie \(category.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Horizontaler Chip-Picker für ItemCategory-Auswahl.
/// Erneutes Tippen auf den aktiven Chip hebt die Auswahl auf.
struct CategoryPickerRow: View {
    /// Binding auf den category-String im ItemFormViewModel.
    @Binding var selectedCategory: String

    private var selected: ItemCategory? {
        ItemCategory.allCases.first { $0.rawValue == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kategorie")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ItemCategory.displayOrder) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selected == category
                        ) {
                            if selected == category {
                                selectedCategory = ""
                            } else {
                                selectedCategory = category.rawValue
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

#Preview {
    @Previewable @State var category = ""
    VStack(spacing: 24) {
        CategoryPickerRow(selectedCategory: $category)
        Text("Ausgewählt: \(category.isEmpty ? "–" : category)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
