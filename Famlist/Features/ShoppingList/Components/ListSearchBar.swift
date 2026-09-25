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
 - Rechts der Scan-Knopf (38, Trefferfläche 44) öffnet den Barcode-Scanner.

 📝 Last Change:
 - Scan-Knopf ergänzt (Handoff 24.09.2026, Barcode-Scanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Tappable search field that opens the search sheet.
struct ListSearchBar: View {
    let t: ListTheme
    var action: () -> Void = {}
    /// Scan-Knopf rechts im Feld → Barcode-Scanner (SPEC §3.2).
    var onScan: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
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
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Artikel suchen oder hinzufügen")

            Button(action: onScan) {
                SVGIcon(Icon.scan, size: 18, color: t.accentText, lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(t.scanBg))
                    .frame(width: 44, height: 44)             // Trefferfläche 44, Optik 38
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -3)                         // 44er-Trefferfläche ohne Layout-Versatz
            .accessibilityLabel("Barcode scannen")
        }
        .padding(.leading, 19)   // 1 border + 18 padding
        .padding(.trailing, 9)   // 1 border + 8 padding
        .frame(height: 52)
        .background(CSSBox(shape: RR(26), paint: .color(t.search), border: 1, borderColor: t.searchBorder, shadows: t.searchShadow))
    }
}

#Preview {
    ListSearchBar(t: ListTheme(.light))
        .padding(20)
}
