/*
 WatchListsScreen.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listen (WatchLists.dc.html): Favorit zuerst; Zeile 56 hoch, padding 0 12, Ring 30, Name Outfit 16/600,
   Status DM 12 weiß .6, Stern 14 accentText (gefüllt).

 🔰 Notes for Beginners:
 - Die Reihenfolge (Favorit oben, dann alphabetisch) legt das ViewModel fest, nicht der Screen.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchListsScreen: View {
    var w = WatchTheme()
    let lists: [WatchListSummary]
    var onSelect: (WatchListSummary) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(lists) { list in row(list) }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .watchScreen("Listen", contentTop: 38, w: w)
    }

    private func row(_ list: WatchListSummary) -> some View {
        Button { onSelect(list) } label: {
            HStack(spacing: 10) {
                WatchRing(w: w, fraction: list.fraction)
                VStack(alignment: .leading, spacing: 1) {
                    Text(list.name).font(WatchFont.outfit(16))
                        .watchLineBox(WatchFont.outfitLineHeight(16))
                    Text(list.status).font(WatchFont.dm(12)).foregroundStyle(w.sub)
                        .watchLineBox(WatchFont.dmLineHeight(12))
                }
                .foregroundStyle(w.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                if list.isFavorite {
                    SVGFilledIcon(Icon.star, size: 14, color: w.accentText, lineWidth: 0)
                }
            }
            .padding(.horizontal, 13)                     // Rand 1 + padding 12 (CSS border-box)
            .frame(minHeight: 56)
            .background(WatchCardBackground(w: w))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(list.name), \(list.status)\(list.isFavorite ? ", Favorit" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Listen") {
    NavigationStack {
        WatchListsScreen(lists: WatchSampleData.lists)
    }
}
