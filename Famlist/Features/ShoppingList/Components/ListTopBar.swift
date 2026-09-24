/*
 ListTopBar.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Top-Bar der Liste: „Aktuelle Liste“ 13/500, darunter 2 pt, Listenname Outfit 30/700 mit Chevron 18.
   Rechts zwei 44er-Kreise mit 10 pt Abstand.

 🔰 Notes for Beginners:
 - Listenname und „Ansicht wechseln“ öffnen beide die Listen-Übersicht.
 - „Mehr“ ist ein System-Menü; dessen Einträge liefert ShoppingListView (Import, Löschen, Profil, Abmelden).

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, an echte Daten angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// List header with list switcher and the two round header buttons.
struct ListTopBar<MoreMenu: View>: View {
    let t: ListTheme
    let title: String
    var onShowLists: () -> Void = {}
    @ViewBuilder let moreMenu: () -> MoreMenu

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onShowLists) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktuelle Liste")
                        .font(AppFont.dm(13, 500))
                        .foregroundStyle(t.sub)
                    HStack(spacing: 6) {
                        Text(title)
                            .font(AppFont.outfit(30, 700))
                            .tracking(-0.6)                      // -0.02em × 30
                            .foregroundStyle(t.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        SVGIcon(Icon.chevronDown, size: 18, color: t.sub, lineWidth: 2.2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Liste wechseln, aktuell \(title)")

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: onShowLists) {
                    RoundHeaderIcon(t: t, icon: Icon.viewToggle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ansicht wechseln")

                Menu(content: moreMenu) {
                    RoundHeaderIcon(t: t, icon: Icon.menu)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityLabel("Mehr")
            }
        }
    }
}

#Preview {
    ListTopBar(t: ListTheme(.light), title: "My List") {
        Button("Profil") {}
    }
    .padding(20)
}
