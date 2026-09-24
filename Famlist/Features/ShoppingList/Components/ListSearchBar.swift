/*
 ListSearchBar.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Suchfeld der Liste: Höhe 52, Radius 26, Lupe 20, Platzhalter „Artikel suchen oder hinzufügen“.

 🔰 Notes for Beginners:
 - Das Feld ist ein Button: Tippen öffnet das Sheet „Artikel suchen“, dort wird getippt.
   So gibt es nur eine Suche mit Katalog-Treffern statt zwei konkurrierender Eingaben.
 - Der Barcode-Knopf aus dem Design fehlt bewusst: Famlist hat keinen Barcode-Scanner.

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen (als Button statt TextField).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Tappable search field that opens the search sheet.
struct ListSearchBar: View {
    let t: ListTheme
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SVGIcon(Icon.search, size: 20, color: t.sub, lineWidth: 2)
                // input::placeholder { color: inherit } → Farbe des Inputs = text
                Text("Artikel suchen oder hinzufügen")
                    .font(AppFont.dm(15, 400))
                    .foregroundStyle(t.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 19)   // 1 border + 18 padding
            .padding(.trailing, 9)   // 1 border + 8 padding
            .frame(height: 52)
            .background(CSSBox(shape: RR(26), paint: .color(t.search), border: 1, borderColor: t.searchBorder, shadows: t.searchShadow))
            .contentShape(RR(26))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Artikel suchen oder hinzufügen")
    }
}

#Preview {
    ListSearchBar(t: ListTheme(.light))
        .padding(20)
}
