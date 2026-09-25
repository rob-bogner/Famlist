/*
 CorePreviews.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vorschauen der Gruppe „Kern“: Design-Liste in 4 Zuständen (Light/Dark, 390 × 844) und alle 7 Dock-Zustände.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Previews/CorePreviews.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: Hybrid – Liste
#Preview("Hybrid – Light", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .light) }
#Preview("Hybrid – Dark", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .dark) }

// MARK: Abgehakt – Zurück
#Preview("Abgehakt – Zurück", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .light, state: .checked) }
#Preview("Abgehakt – Zurück – Dark", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .dark, state: .checked) }

// MARK: Wisch-Aktionen
#Preview("Wisch-Aktionen", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .light, state: .swipe) }
#Preview("Wisch-Aktionen – Dark", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .dark, state: .swipe) }

// MARK: Leere Liste
#Preview("Leere Liste", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .light, state: .empty) }
#Preview("Leere Liste – Dark", traits: .fixedLayout(width: 390, height: 844)) { DesignListScreen(appearance: .dark, state: .empty) }

// MARK: Dock – alle Zustände
#Preview("Dock – alle Zustände", traits: .sizeThatFitsLayout) { CoreDockStatesBoard() }

/// Vereinfachte Tabelle wie DockStates.dc.html: Zeile je Zustand, links Light, rechts Dark.
private struct CoreDockStatesBoard: View {
    private struct Row: Identifiable {
        let id: String
        let active: DockActive
        let pill: DockPill
    }

    private let rows: [Row] = [
        Row(id: "Standard", active: .none, pill: .open),
        Row(id: "Sortieren geöffnet", active: .sort, pill: .open),
        Row(id: "Kopieren geöffnet", active: .copy, pill: .open),
        Row(id: "Kopiert", active: .copied, pill: .open),
        Row(id: "Löschen geöffnet", active: .delete, pill: .open),
        Row(id: "Alles erledigt", active: .none, pill: .allDone),
        Row(id: "Leere Liste", active: .none, pill: .empty)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { r in
                HStack(spacing: 0) {
                    Text(r.id)
                        .font(AppFont.dm(16, 700))
                        .foregroundStyle(Color.hex("#0F2528"))
                        .frame(width: 180, alignment: .leading)
                        .padding(.horizontal, 24)
                    DockView(appearance: .light, accentHex: "#0FA3AE", active: r.active, pill: r.pill)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                        .background(Color.white)
                    DockView(appearance: .dark, accentHex: "#1FC2CC", active: r.active, pill: r.pill)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                        .background {
                            // radial-gradient(120% 140% at 50% 100%, rgba(31,194,204,.08), transparent 60%), #071012
                            ZStack {
                                Color.hex("#071012")
                                CSSRadialGradient(center: UnitPoint(x: 0.5, y: 1), extent: .ellipse(rx: 1.2, ry: 1.4),
                                                  stops: [stop(.rgba(31, 194, 204, 0.08), 0), stop(.rgba(31, 194, 204, 0), 0.6)])
                            }
                        }
                }
            }
        }
        .padding(40)
        .background(Color.hex("#F6F9F9"))
    }
}
