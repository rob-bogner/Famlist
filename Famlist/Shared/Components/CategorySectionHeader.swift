/*
 CategorySectionHeader.swift

 Famlist
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Reusable Section-Header-Komponente für Kategorieabschnitte in der ListView.

 🛠 Includes:
 - SF Symbol Icon, Kategoriename, Artikel-Anzahl
 - Konsistentes Design mit bestehendem SectionHeader

 📝 Last Change:
 - Initial creation (FAM-64)
 ------------------------------------------------------------------------
*/

import SwiftUI

/// Section Header mit Kategorie-Icon, -Name und Artikel-Anzahl.
struct CategorySectionHeader: View {
    let category: ItemCategory
    let itemCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.accentColor)
            Text(category.rawValue)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
            Text("\(itemCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.theme.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.rawValue), \(itemCount) Artikel")
    }
}

#Preview {
    VStack(spacing: 0) {
        CategorySectionHeader(category: .milch, itemCount: 3)
            .padding(.horizontal)
        Divider()
        CategorySectionHeader(category: .obstGemuese, itemCount: 1)
            .padding(.horizontal)
        Divider()
        CategorySectionHeader(category: .sonstiges, itemCount: 5)
            .padding(.horizontal)
    }
    .padding(.vertical)
}
