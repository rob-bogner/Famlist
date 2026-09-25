/*
 ListTopBar.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kopfzeile der Liste: Listenname Outfit 30/700 mit Chevron 18, rechts EIN 44er-Kreis „Mehr“ (☰).

 🔰 Notes for Beginners:
 - Der Listenname öffnet „Meine Listen“, ☰ das Kontext-Menü (MenuOverlayScreen).
 - „Aktuelle Liste“ und „Ansicht wechseln“ sind laut Redesign entfallen (SPEC Phase 2).

 📝 Last Change:
 - An ListScreen des Handoffs vom 24.09.2026 angeglichen (ein Knopf, ohne Label).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// List header with list switcher and the round „Mehr“ button.
struct ListTopBar: View {
    let t: ListTheme
    let title: String
    var onShowLists: () -> Void = {}
    var onMenu: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onShowLists) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(AppFont.outfit(30, 700))
                        .tracking(-0.6)                      // -0.02em × 30
                        .foregroundStyle(t.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    SVGIcon(Icon.chevronDown, size: 18, color: t.sub, lineWidth: 2.2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Liste wechseln, aktuell \(title)")

            Spacer(minLength: 0)

            Button(action: onMenu) {
                RoundHeaderIcon(t: t, icon: Icon.menu)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mehr")
        }
    }
}

#Preview {
    ListTopBar(t: ListTheme(.light), title: "My List")
        .padding(20)
}

#Preview("Dark") {
    ListTopBar(t: ListTheme(.dark), title: "My List")
        .padding(20)
        .background(Color.hex("#0A1416"))
}
