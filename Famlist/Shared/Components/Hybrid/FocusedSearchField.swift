/*
 FocusedSearchField.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Suchfeld der Sheet „Artikel suchen“: Höhe 54, Pille, Rahmen 1,5 in Akzent, 4-pt-Ring + Glow.

 🔰 Notes for Beginners:
 - Der Löschen-Knopf (Kreis 40) erscheint, sobald Text eingegeben ist.
 - Den Textcursor zeichnet iOS selbst in Akzentfarbe (`.tint`). Der statische Design-Cursor
   aus dem Mockup entfällt deshalb.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen, an echte Eingabe und Fokus angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Fokussiertes Suchfeld (Höhe 54, Pille, Rahmen 1,5 in Akzent, 4-pt-Ring + Glow).
struct FocusedSearchField: View {
    let k: SheetTheme
    @Binding var text: String
    let placeholder: String
    var focus: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}

    private var showsClear: Bool { !text.isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: k.accentText, lineWidth: 2)
            // Platzhalterfarbe = Browser-Standard aus dem Design: #757575.
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.hex("#757575")))
                .font(AppFont.dm(16, text.isEmpty ? 400 : 500))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .focused(focus)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .accessibilityLabel("Artikel suchen")
            if showsClear {
                Button(action: { text = "" }) {
                    SVGIcon(Icon.close, size: 14, color: k.icon, lineWidth: 2.6)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(k.close))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche leeren")
            }
        }
        .padding(.leading, 17.5)                        // 1,5 border + 16 padding
        .padding(.trailing, showsClear ? 7.5 : 17.5)   // 1,5 border + 6 / 16 padding
        .frame(height: 54)
        .background(CSSBox(shape: Pill, paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                           shadows: [.drop(0, 0, 0, 4, k.ringSoft), .drop(0, 8, 20, -12, k.ringGlow)]))
    }
}

#Preview {
    @Previewable @State var text = "Milch"
    @Previewable @FocusState var focused: Bool
    FocusedSearchField(k: SheetTheme(.light), text: $text, placeholder: "Artikel suchen …", focus: $focused)
        .padding(20)
}
