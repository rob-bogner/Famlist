/*
 DesignListSearchField.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Suchfeld der statischen Design-Liste für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Suche

struct DesignListSearchField: View {
    let t: ListTheme
    @Binding var query: String

    var body: some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: t.sub, lineWidth: 2)
            TextField("", text: $query,
                      // input::placeholder { color: inherit } → Farbe des Inputs = text
                      prompt: Text("Artikel suchen oder hinzufügen").foregroundStyle(t.text))
                .font(AppFont.dm(15, 400))
                .foregroundStyle(t.text)
                .tint(t.accent)
                .accessibilityLabel("Artikel suchen oder hinzufügen")
            Button(action: {}) {
                SVGIcon(Icon.scan, size: 18, color: t.accentText, lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(t.scanBg))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Barcode scannen")
        }
        .padding(.leading, 19)   // 1 border + 18 padding
        .padding(.trailing, 9)   // 1 border + 8 padding
        .frame(height: 52)
        .background(CSSBox(shape: RR(26), paint: .color(t.search), border: 1, borderColor: t.searchBorder, shadows: t.searchShadow))
    }
}

#Preview("Suchfeld") {
    DesignListSearchField(t: ListTheme(.light), query: .constant(""))
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Suchfeld – Dark") {
    DesignListSearchField(t: ListTheme(.dark), query: .constant(""))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
