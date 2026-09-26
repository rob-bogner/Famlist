/*
 ListSearchBar.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Filterfeld der Liste (Ruhezustand): Höhe 52, Radius 26, Lupe 20, Platzhalter „In dieser Liste filtern“.

 🔰 Notes for Beginners:
 - Das Feld ist ein Button: Tippen schaltet den Listenkopf in den Filter-Modus (ListFilterField).
 - Filtern durchsucht nur die Artikel dieser Liste. Hinzufügen läuft über das Plus im Dock (InlineAddOverlay),
   der Barcode-Scanner sitzt jetzt dort im Eingabefeld.

 📝 Last Change:
 - Suche → Filter (Canvas SearchInline), Scan-Knopf ins Hinzufügen-Feld verschoben.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Tappable filter field: opens the list filter (ListFilterField). Adding items runs through the dock's „+“.
struct ListSearchBar: View {
    let t: ListTheme
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SVGIcon(Icon.search, size: 20, color: t.sub, lineWidth: 2)
                // input::placeholder { color: inherit } → Farbe des Inputs = text
                Text("In dieser Liste filtern")
                    .font(AppFont.dm(15, 400))
                    .foregroundStyle(t.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)                     // XXL: bis zur Designgröße 15 schrumpfen statt abschneiden
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 19)   // 1 border + 18 padding
            .frame(height: 52)
            .contentShape(RR(26))
        }
        .buttonStyle(.plain)
        .background(CSSBox(shape: RR(26), paint: .color(t.search), border: 1, borderColor: t.searchBorder, shadows: t.searchShadow))
        .accessibilityLabel("In dieser Liste filtern")
    }
}

#Preview {
    ListSearchBar(t: ListTheme(.light))
        .padding(20)
}

#Preview("Dark") {
    ListSearchBar(t: ListTheme(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
