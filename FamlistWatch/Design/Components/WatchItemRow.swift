/*
 WatchItemRow.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikelzeile (WatchList.dc.html): 46 hoch, padding 0 12, Radius 18, Kreis 26, Abstand 10,
   Name DM 15/500 (…), Menge DM 12 weiß .6. Erledigt: ganze Zeile 55 %, Name durchgestrichen.
 - CSS border-box: Der 1-px-Rand liegt vor dem Innenabstand, Inhalt also 13 pt vom Kartenrand.

 🔰 Notes for Beginners:
 - Zwei Tippziele: Der linke Bereich (Randabstand + Kreis + halber Abstand = 43 pt) hakt ab, der Rest
   öffnet den Artikel. Die Pixel bleiben gleich, nur die Trefferfläche des Kreises ist größer als 26 pt.
 - Bei großer Schrift wächst die Zeile (minHeight 46) statt Text abzuschneiden.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchItemRow: View {
    var w = WatchTheme()
    let name: String
    let quantity: String
    var isChecked = false
    var onToggle: () -> Void = {}
    var onOpen: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                WatchCheckCircle(w: w, isChecked: isChecked)
                    .padding(.leading, 13)                // Rand 1 + padding 12 (CSS border-box)
                    .padding(.trailing, 5)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "\(name) wieder offen" : "\(name) abhaken")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(WatchFont.dm(15, 500)).strikethrough(isChecked).lineLimit(1)
                        .watchLineBox(WatchFont.dmLineHeight(15, 500))
                    Text(quantity).font(WatchFont.dm(12)).foregroundStyle(w.sub).lineLimit(1)
                        .watchLineBox(WatchFont.dmLineHeight(12))
                }
                .foregroundStyle(w.text)
                .padding(.leading, 5)
                .padding(.trailing, 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), \(quantity)\(isChecked ? ", erledigt" : "")")
            .accessibilityHint("Öffnet den Artikel")
        }
        .frame(minHeight: 46)
        .background(WatchCardBackground(w: w))
        .opacity(isChecked ? 0.55 : 1)
    }
}

#Preview {
    VStack(spacing: 6) {
        WatchItemRow(name: "Bananen", quantity: "6 Stück")
        WatchItemRow(name: "Äpfel", quantity: "1 kg", isChecked: true)
    }
    .padding(12)
    .background(Color.black)
}
