/*
 ReceiptAssignChoices.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt der Aktionskarte „Bon-Zeile zuordnen“ (Canvas: ReceiptAssignDialog): Bon-Zeile als Beleg
   und darunter die vorgeschlagenen Artikel zum Antippen.

 🔰 Notes for Beginners:
 - Bon-Zeile: Monospace 14, Preis rechts 600, Fläche field, gestrichelter Rand, Radius 16, Padding 10 / 14.
 - Auswahl: Karte (field, Rand, Radius 20) mit Zeilen ab 58 hoch – Kachel 36 (Radius 12, Akzent-Ton)
   mit Einkaufswagen, Name 15/600, beim ersten Treffer das Etikett „Vorschlag“, Pfeil rechts.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Receipt line plus tappable item suggestions inside the "assign" action card.
struct ReceiptAssignChoices: View {
    let k: SheetTheme
    let raw: String
    let price: String
    let suggestions: [String]
    let onPick: (String) -> Void

    var body: some View {
        let d = ActionCardTokens(k)
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(raw)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(price)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(d.text)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(CSSBox(shape: RR(16), paint: .color(d.field), border: 1, borderColor: d.fieldBorder, dash: [4, 3]))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bon-Zeile \(raw), \(price)")

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, name in
                        if index > 0 { Rectangle().fill(d.line).frame(height: 1) }
                        row(name, isSuggestion: index == 0, d: d)
                    }
                }
                .background(CSSBox(shape: RR(20), paint: .color(d.field), border: 1, borderColor: d.fieldBorder))
                .clipShape(RR(20))
            }
        }
    }

    private func row(_ name: String, isSuggestion: Bool, d: ActionCardTokens) -> some View {
        Button(action: { onPick(name) }) {
            HStack(spacing: 12) {
                SVGIcon(Icon.cart, size: 18, color: d.info, lineWidth: 1.9)
                    .frame(width: 36, height: 36)
                    .background(RR(12).fill(d.chip))
                    .accessibilityHidden(true)
                Text(name)
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(d.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSuggestion {
                    Text("Vorschlag")
                        .font(AppFont.dm(11, 600))
                        .foregroundStyle(d.info)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(d.chip))
                }
                SVGIcon(Icon.arrowRight, size: 18, color: d.sub, lineWidth: 2)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSuggestion ? "\(name), Vorschlag" : name)
    }
}

#Preview {
    ReceiptAssignChoices(k: SheetTheme(.light), raw: "KOKOSM. 400ML", price: "1,39 €",
                         suggestions: ["Kokosmilch", "Kokosmilch Bio"], onPick: { _ in })
        .padding(20)
}

#Preview("Dark") {
    ReceiptAssignChoices(k: SheetTheme(.dark), raw: "KOKOSM. 400ML", price: "1,39 €",
                         suggestions: ["Kokosmilch", "Kokosmilch Bio"], onPick: { _ in })
        .padding(20)
        .background(Color.black)
}
