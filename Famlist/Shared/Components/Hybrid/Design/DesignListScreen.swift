/*
 DesignListScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Statische Design-Liste mit Beispieldaten. Dient nur als Hintergrund in Vorschauen der Sheets und Overlays.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListScreen.swift (ListScreen → DesignListScreen, private Bausteine mit Präfix „Design“; Glow-Kreise liegen in ListBackground der App).
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 - Bausteine in eigene Dateien ausgelagert (DesignListTopBar, DesignListSearchField, DesignProgressHero,
   DesignListTabs, DesignSectionHeader, DesignItemRow, DesignListEmptyState; Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct DesignListScreen: View {
    let appearance: Appearance
    let accentHex: String?
    let state: ListRowState
    /// Optional: echter Hintergrund-Blur unter dem Dock (im Design `backdrop-filter`).
    /// Im statischen Design liegt nichts hinter dem Dock – deshalb standardmäßig aus.
    let liveDockBlur: Bool

    @State private var query = ""

    init(appearance: Appearance, accentHex: String? = nil, state: ListRowState = .normal, liveDockBlur: Bool = false) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.state = state
        self.liveDockBlur = liveDockBlur
    }

    /// pillState im HTML: empty → .empty, checked → .allDone, sonst .open
    private var dockPill: DockPill {
        switch state {
        case .empty: .empty
        case .checked: .allDone
        case .normal, .swipe: .open
        }
    }

    var body: some View {
        let t = ListTheme(appearance, accentHex: accentHex)
        ZStack(alignment: .topLeading) {
            ListBackground(t: t)

            VStack(alignment: .leading, spacing: 0) {
                DesignListTopBar(t: t)
                DesignListSearchField(t: t, query: $query)
                    .padding(.top, 18)
                DesignProgressHero(t: t, state: state)
                    .padding(.top, 18)
                DesignListTabs(t: t)
                    .padding(.top, 18)
                if state == .empty {
                    DesignListEmptyState(t: t)
                        .padding(.top, 44)             // gap 18 + margin-top 26
                } else {
                    DesignSectionHeader(t: t, checked: state == .checked)
                        .padding(.top, 16)             // gap 18 + margin-top −2
                    DesignItemRow(t: t, state: state)
                        .padding(.top, 12)             // gap 18 + margin-top −6
                }
            }
            .padding(.top, 62)
            .padding(.horizontal, 20)

            // position: absolute; left: 20; bottom: 34; 350 × 64
            DockView(appearance: appearance, accentHex: accentHex, active: .none, pill: dockPill, liveBlur: liveDockBlur)
                .frame(height: 64)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .ignoresSafeArea()
    }
}

#Preview("DesignListScreen", traits: .fixedLayout(width: 390, height: 844)) {
    DesignListScreen(appearance: .light)
}

#Preview("DesignListScreen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    DesignListScreen(appearance: .dark)
}
