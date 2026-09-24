/*
 ListSectionHeader.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sektions-Kopf der Liste. Zwei Varianten:
   • Kategorie: Icon-Kachel mit Akzent-Verlauf, Name Outfit 20/600, Anzahl, rechts „Alle abhaken ›“.
   • Abgehakt: graue Kachel mit Haken, „Abgehakte Artikel“ in sub, Anzahl.

 🔰 Notes for Beginners:
 - Ersetzt CategorySectionHeader. Name und Icon kommen aus der Kategorie des Nutzers (CategoryDefinition).
 - „Alle abhaken“ hakt nur die offenen Artikel dieser Kategorie ab.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an echte Kategorien angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Section header for a category group or the checked-items group.
struct ListSectionHeader: View {
    enum Kind {
        case category(CategoryDefinition)
        case checked
    }

    let t: ListTheme
    let kind: Kind
    let count: Int
    var onCheckAll: () -> Void = {}

    var body: some View {
        switch kind {
        case .category(let category):
            categoryHeader(category)
        case .checked:
            checkedHeader
        }
    }

    private func categoryHeader(_ category: CategoryDefinition) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                SVGIcon(category.svgIcon, size: 16, color: .white, lineWidth: 2.1)
                    .frame(width: 30, height: 30)
                    .background(CSSBox(shape: RR(10), paint: t.chipGrad, shadows: t.chipShadow))
                Text(category.name)
                    .font(AppFont.outfit(20, 600))
                    .foregroundStyle(t.text)
                    .lineLimit(1)
                Text("\(count)")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(t.sub)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(category.name), \(count) Artikel")
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onCheckAll) {
                HStack(spacing: 4) {
                    Text("Alle abhaken")
                        .font(AppFont.dm(14, 600))
                        .foregroundStyle(t.accentText)
                    SVGIcon(Icon.chevronRight, size: 16, color: t.accentText, lineWidth: 2.2)
                }
                .padding(.vertical, 10)
                .padding(.leading, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Alle \(category.name) abhaken")
        }
    }

    private var checkedHeader: some View {
        HStack(spacing: 10) {
            SVGIcon(Icon.check, size: 16, color: t.sub, lineWidth: 2.2)
                .frame(width: 30, height: 30)
                .background(CSSBox(shape: RR(10), paint: .color(t.search), border: 1, borderColor: t.searchBorder))
            Text("Abgehakte Artikel")
                .font(AppFont.outfit(20, 600))
                .foregroundStyle(t.sub)
            Text("\(count)")
                .font(AppFont.dm(14, 600))
                .foregroundStyle(t.sub)
        }
        .frame(minHeight: 38)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Abgehakte Artikel, \(count)")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(spacing: 20) {
        ListSectionHeader(t: ListTheme(.light), kind: .category(CategoryDefinition.defaults[7]), count: 1)
        ListSectionHeader(t: ListTheme(.light), kind: .checked, count: 1)
    }
    .padding(20)
}
