/*
 InsightSearchField.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Suchfeld „Produkt suchen“ im Reiter „Verbrauch“ (Board InsightUsage).

 🔰 Notes for Beginners:
 - Board: Höhe 44, Innenabstand 14 (+1 Rahmen), Radius 16, field-Hintergrund, Rahmen fieldBorder, Abstand 10;
   Lupe 18 (Strich 2) und Text 15 in sub.
 - Eigener Platzhalter statt `prompt` (Muster „Artikel verwalten“): schrumpft bei großer Schrift, statt
   abgeschnitten zu werden.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InsightSearchField: View {
    @Binding var text: String
    let k: SheetTheme
    var placeholder = "Produkt suchen"

    var body: some View {
        HStack(spacing: 10) {
            SVGIcon(ReceiptMetaIcon.search, size: 18, color: k.sub, lineWidth: 2)
            TextField("", text: $text)
                .font(AppFont.dm(15, 400))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(placeholder)
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(AppFont.dm(15, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                            .minimumScaleFactor(1 / AppFont.maxScale)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        }
        .padding(.horizontal, 15)                    // 14 + 1 Rahmen
        .frame(height: 44)
        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }
}

#Preview("Produkt suchen") {
    InsightSearchField(text: .constant(""), k: SheetTheme(.light)).padding()
}

#Preview("Produkt suchen – Dark") {
    InsightSearchField(text: .constant("Milch"), k: SheetTheme(.dark)).padding().background(Color.black)
}
