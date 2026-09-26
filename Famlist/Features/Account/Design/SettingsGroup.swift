/*
 SettingsGroup.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gruppe in den Einstellungen: Radius 20, card, Rahmen 1 cardBorder, ohne Schatten.

 🔰 Notes for Beginners:
 - Aus SettingsSheet.swift ausgelagert (Datei über 300 Zeilen); unverändert übernommen.

 📝 Last Change:
 - Ausgelagert aus SettingsSheet.swift (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Gruppe: Radius 20, card, Rahmen 1 cardBorder, overflow hidden, kein Schatten.
struct SettingsGroup<Content: View>: View {
    let t: ListAccountTokens
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(1)                                          // Rahmen
        .clipShape(RR(20))
        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder))
    }
}

#Preview {
    let t = ListAccountTokens(.light)
    SettingsGroup(t: t) {
        SettingsRow(t: t, title: "Preise anzeigen", titleColor: t.k.text, subtitle: "Auf Artikelkarten", hasTopLine: false) {
            EmptyView()
        }
    }
    .padding(20)
}

#Preview("Dark") {
    let t = ListAccountTokens(.dark)
    SettingsGroup(t: t) {
        SettingsRow(t: t, title: "Preise anzeigen", titleColor: t.k.text, subtitle: "Auf Artikelkarten", hasTopLine: false) {
            EmptyView()
        }
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
