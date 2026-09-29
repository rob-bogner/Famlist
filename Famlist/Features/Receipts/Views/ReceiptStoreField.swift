/*
 ReceiptStoreField.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt der Aktionskarte „Laden ändern“ (Canvas: ReceiptStoreAlert): Eingabefeld + Schnellauswahl.

 🔰 Notes for Beginners:
 - Feld: 52 hoch, Radius 18, field-Fläche mit Rand, Laden-Symbol 18 links, Text 16/500.
 - Schnellauswahl (4 Läden): Glas-Pillen 34 hoch (aktiver Laden in Akzent, sonst neutral), Text 13/600, Abstand 8.
   Tippen übernimmt den Namen ins Feld (gespeichert wird erst mit „Übernehmen“).

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Store name field with quick-pick chips inside the "change store" action card.
struct ReceiptStoreField: View {
    let k: SheetTheme
    @Binding var text: String
    let stores: [String]

    var body: some View {
        let d = ActionCardTokens(k)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SVGIcon(Icon.store, size: 18, color: d.sub, lineWidth: 2)
                    .accessibilityHidden(true)
                TextField("z. B. EDEKA", text: $text)
                    .font(AppFont.dm(16, 500))
                    .foregroundStyle(d.text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityLabel("Laden")
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(CSSBox(shape: RR(18), paint: .color(d.field), border: 1, borderColor: d.fieldBorder))

            HStack(spacing: 8) {
                ForEach(stores, id: \.self) { store in
                    chip(store, isOn: store.caseInsensitiveCompare(text.trimmingCharacters(in: .whitespaces)) == .orderedSame, d: d)
                }
            }
        }
    }

    private func chip(_ store: String, isOn: Bool, d: ActionCardTokens) -> some View {
        Button(action: { text = store }) {
            Text(store)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(isOn ? .white : d.text)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(GlassPillBackground(style: isOn ? .accent : .neutral, appearance: k.appearance,
                                                accent: k.a, height: 34))
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var text = "EDEKA"
    ReceiptStoreField(k: SheetTheme(.light), text: $text, stores: ["REWE", "EDEKA", "Lidl", "ALDI", "Netto"])
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var text = "EDEKA"
    ReceiptStoreField(k: SheetTheme(.dark), text: $text, stores: ["REWE", "EDEKA", "Lidl", "ALDI", "Netto"])
        .padding(20)
        .background(Color.black)
}
