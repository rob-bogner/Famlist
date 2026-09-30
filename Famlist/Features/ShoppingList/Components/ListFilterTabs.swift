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
 - „Offen“ / „Erledigt“ mit Anzahl-Plakette (30.09.2026).
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an den Filter angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Filter tabs with animated accent underline.
struct ListFilterTabs: View {
    let t: ListTheme
    @Binding var selection: ItemFilter
    /// Anzahl hinter „Offen“ / „Erledigt“ (nil = keine Plakette).
    var openCount: Int? = nil
    var doneCount: Int? = nil

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
            HStack(spacing: 6) {
                Text(filter.rawValue)
                    .font(AppFont.dm(15, active ? 600 : 500))
                    .foregroundStyle(active ? t.accentText : t.sub)
                if let count = count(for: filter) {
                    badge(count, active: active)
                }
            }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(filter.rawValue)
        .accessibilityValue(count(for: filter).map { "\($0) Artikel" } ?? "")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private func count(for filter: ItemFilter) -> Int? {
        switch filter {
        case .all: return nil
        case .open: return openCount
        case .done: return doneCount
        }
    }

    /// Plakette 20 hoch, Radius 10, 12/600; gewählt Akzent 12 % (Dark 20 %), sonst #EEF3F3 bzw. Weiß 8 %.
    private func badge(_ count: Int, active: Bool) -> some View {
        Text("\(count)")
            .font(AppFont.dm(12, 600))
            .monospacedDigit()
            .foregroundStyle(active ? t.accentText : t.sub)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(active ? t.a.base.color(t.isDark ? 0.2 : 0.12)
                                              : (t.isDark ? Color.rgba(255, 255, 255, 0.08) : .hex("#EEF3F3"))))
            .contentTransition(.numericText())
            .animation(.snappy, value: count)
    }
}

#Preview {
    @Previewable @State var filter = ItemFilter.all
    ListFilterTabs(t: ListTheme(.light), selection: $filter, openCount: 12, doneCount: 3)
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var filter = ItemFilter.all
    ListFilterTabs(t: ListTheme(.dark), selection: $filter, openCount: 0, doneCount: 5)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
