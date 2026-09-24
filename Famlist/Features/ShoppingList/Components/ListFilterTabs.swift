/*
 ListFilterTabs.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tabs „Alle · Offen · Erledigt“: 26 pt Abstand, Text 10 oben / 12 unten, Unterstrich 3 pt, Trennlinie 1.

 🔰 Notes for Beginners:
 - Die Auswahl ist ListViewModel.itemFilter (reiner Anzeige-Filter, nicht synchronisiert).
 - Der Unterstrich wandert per matchedGeometryEffect zum gewählten Tab.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an den Filter angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Filter tabs with animated accent underline.
struct ListFilterTabs: View {
    let t: ListTheme
    @Binding var selection: ItemFilter

    @Namespace private var underline

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 26) {
                ForEach(ItemFilter.allCases) { filter in
                    tab(filter)
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zIndex(1) // Unterstrich liegt über der Trennlinie
            Rectangle()
                .fill(t.line)
                .frame(height: 1)
        }
    }

    private func tab(_ filter: ItemFilter) -> some View {
        let active = selection == filter
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selection = filter }
        }) {
            Text(filter.rawValue)
                .font(AppFont.dm(15, active ? 600 : 500))
                .foregroundStyle(active ? t.accentText : t.sub)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    if active {
                        UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3, style: .circular)
                            .fill(t.accent)
                            .frame(height: 3)
                            .shadow(color: t.accentGlow, radius: 6)   // 0 0 12px rgba(accent,.6)
                            .offset(y: 1)                              // bottom: -1px
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var filter = ItemFilter.all
    ListFilterTabs(t: ListTheme(.light), selection: $filter)
        .padding(20)
}
