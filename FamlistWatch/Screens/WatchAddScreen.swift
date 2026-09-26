/*
 WatchAddScreen.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hinzufügen (WatchAdd.dc.html): Eingabe mit Mikrofon (System-Eingabe mit Diktat) und „Oft gekauft“.

 🔰 Notes for Beginners:
 - TextFieldLink öffnet die watchOS-Eingabe (Diktat, Kritzeln, Tastatur). Das Aussehen der Pille
   bestimmt das Label – so bleibt das Design pixelgenau.
 - Eingabe: 48 hoch, Radius 24, padding 0 6 0 14, Karte ohne Innenlicht, Platzhalter weiß .6,
   Mikrofon-Orb 36 (Icon 18/2). Zeilen „Oft gekauft“: 46 hoch, Plus-Kreis 28 (Chip), Plus 14/3.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchAddScreen: View {
    var w = WatchTheme()
    let frequent: [WatchFrequentItem]
    var onAdd: (String) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                input
                if !frequent.isEmpty {
                    WatchSectionLabel(w: w, text: "Oft gekauft")
                    ForEach(frequent) { item in frequentRow(item) }
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .watchScreen("Hinzufügen", contentTop: 38, w: w)
    }

    private var input: some View {
        TextFieldLink(prompt: Text("Artikel")) {
            HStack(spacing: 8) {
                Text("Artikel …").font(WatchFont.dm(15)).foregroundStyle(w.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SVGIcon(WatchIcon.mic, size: 18, color: .white, lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .background(CSSBox(shape: Circle(), paint: w.fab, shadows: w.fabShadow))
            }
            .padding(.leading, 15).padding(.trailing, 7)       // Rand 1 + padding 0 6 0 14 (CSS border-box)
            .frame(minHeight: 48)
            .background(WatchCardBackground(w: w, radius: 24, innerHighlight: false))
            .contentShape(Rectangle())
        } onSubmit: { text in
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { onAdd(name) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Artikel diktieren oder eingeben")
    }

    private func frequentRow(_ item: WatchFrequentItem) -> some View {
        Button { onAdd(item.name) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(WatchFont.dm(15, 500)).lineLimit(1)
                        .watchLineBox(WatchFont.dmLineHeight(15, 500))
                    Text(item.detail).font(WatchFont.dm(12)).foregroundStyle(w.sub).lineLimit(1)
                        .watchLineBox(WatchFont.dmLineHeight(12))
                }
                .foregroundStyle(w.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                SVGIcon(Icon.plus, size: 14, color: w.accentText, lineWidth: 3)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(w.chip))
            }
            .padding(.horizontal, 13)                         // Rand 1 + padding 12
            .frame(minHeight: 46)
            .background(WatchCardBackground(w: w))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name) hinzufügen")
    }
}

#Preview("Hinzufügen") {
    NavigationStack {
        WatchAddScreen(frequent: WatchSampleData.frequent)
    }
}
