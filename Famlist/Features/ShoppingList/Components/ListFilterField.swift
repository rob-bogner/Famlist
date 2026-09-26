/*
 ListFilterField.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Aktives Filterfeld im Listenkopf (Canvas SearchInline „Liste filtern“): filtert live die Artikel dieser Liste.

 🔰 Notes for Beginners:
 - 52 hoch, Radius 26, Rand 1,5 ring, Ring 4 ringSoft; Lupe 20 in Akzenttext; rechts neutraler Glas-Knopf ✕ 40.
 - ✕ hebt den Filter auf. Verliert das leere Feld den Fokus, endet der Filter-Modus ebenfalls.
 - Tastatur-Taste „Fertig“ blendet nur die Tastatur aus, der Filter bleibt stehen.

 📝 Last Change:
 - Initial creation (Suche → Filter, Hinzufügen über das Plus).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ListFilterField: View {
    let t: ListTheme
    @Binding var query: String
    var onClear: () -> Void = {}
    var onFocusLostWhileEmpty: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        let k = SheetTheme(t.appearance)
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: k.accentText, lineWidth: 2)
            TextField("", text: $query, prompt: Text("In dieser Liste filtern").foregroundStyle(k.sub))
                .font(AppFont.dm(16, 500))
                .foregroundStyle(k.text)
                .tint(k.a.base.color())
                .focused($focused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .onSubmit { focused = false }
                .accessibilityLabel("In dieser Liste filtern")
            GlassCircleButton(style: .neutral, appearance: t.appearance, accent: t.a, icon: Icon.close,
                              label: "Filter aufheben", size: 40, lineWidth: 2.4) {
                focused = false
                onClear()
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(height: 52)
        .background(CSSBox(shape: RR(26), paint: .color(t.isDark ? .hex("#102124") : .white), border: 1.5,
                           borderColor: k.ring,
                           shadows: [.drop(0, 0, 0, 4, k.ringSoft), .drop(0, 8, 20, -12, k.ringGlow)]))
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onChange(of: focused) { _, isFocused in
            if !isFocused && query.trimmingCharacters(in: .whitespaces).isEmpty { onFocusLostWhileEmpty() }
        }
    }
}

#Preview("Filterfeld") {
    @Previewable @State var q = "milch"
    ListFilterField(t: ListTheme(.light), query: $q)
        .padding(20)
}

#Preview("Filterfeld – Dark") {
    @Previewable @State var q = "milch"
    ListFilterField(t: ListTheme(.dark), query: $q)
        .padding(20)
        .background(Color.hex("#071012"))
}
