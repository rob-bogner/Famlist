/*
 WatchListScreen.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einkaufsliste (WatchList.dc.html): Fortschritt „2 von 6 erledigt“ + Balken, Abschnitte nach
   Kategorie, Artikelzeilen; unten Verlauf zu Schwarz, „Alle abhaken“ links und FAB rechts.

 🔰 Notes for Beginners:
 - Nur Anzeige und Rückrufe; Daten und Aktionen kommen aus dem ViewModel (Phase 5).
 - Maße: Inhalt links/rechts 12, Abstand 6; Knöpfe 10 vom Rand, 8 von unten; Verlauf 70 hoch.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchListScreen: View {
    var w = WatchTheme()
    let title: String
    let checked: Int
    let total: Int
    let sections: [WatchSectionDisplay]
    var onToggle: (String) -> Void = { _ in }
    var onOpen: (String) -> Void = { _ in }
    var onCheckAll: () -> Void = {}
    var onAdd: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    progress
                    ForEach(sections) { section in
                        WatchSectionLabel(w: w, text: section.title)
                        ForEach(section.items) { item in
                            WatchItemRow(w: w, name: item.name, quantity: item.quantity, isChecked: item.isChecked,
                                         onToggle: { onToggle(item.id) }, onOpen: { onOpen(item.id) })
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 58)                     // Platz für die Knöpfe unten
            }
            .scrollIndicators(.hidden)
            bottomFade
            HStack {
                WatchGlassButton(w: w, icon: WatchIcon.checkAll, label: "Alle abhaken", action: onCheckAll)
                Spacer()
                WatchFab(w: w, action: onAdd)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .watchScreen(title, contentTop: 38, w: w)
    }

    /// „2 von 6 erledigt“ (DM 12, Zahl weiß 600) + Balken; Abstand 5, padding 0 4 2 4.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 5) {
            (Text("\(checked)").foregroundStyle(.white).font(WatchFont.dm(12, 600))
             + Text(" von \(total) erledigt").foregroundStyle(w.sub).font(WatchFont.dm(12)))
                .watchLineBox(WatchFont.dmLineHeight(12))
            WatchProgressBar(w: w, fraction: total == 0 ? 0 : Double(checked) / Double(total))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(checked) von \(total) erledigt")
    }

    /// Verlauf unten: 70 hoch, transparent → Schwarz .85 bei 55 %.
    private var bottomFade: some View {
        LinearGradient(stops: [.init(color: .black.opacity(0), location: 0),
                               .init(color: .black.opacity(0.85), location: 0.55)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 70)
            .allowsHitTesting(false)
    }
}

#Preview("Liste") {
    NavigationStack {
        WatchListScreen(title: "My List", checked: 2, total: 6, sections: WatchSampleData.sections)
    }
}
