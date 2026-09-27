/*
 KeyboardRevealScrollView.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - ScrollView für Formulare in eigenen Sheets: Bei offener Tastatur endet sie über Tastatur und schwebenden
   Knöpfen und holt das fokussierte Feld (`.revealsWhenFocused`) in den sichtbaren Bereich.

 🔰 Notes for Beginners:
 - Die Hybrid-Sheets liegen in einer Ebene, die den Tastatur-Bereich ignoriert (ShoppingListView). iOS scrollt
   fokussierte Felder dort nicht von selbst nach oben – das übernimmt diese View.
 - `bottomInset` rechnet der Aufrufer aus: um wie viel die sichtbare Fläche bei offener Tastatur unten endet
   (z. B. Tastatur + 14 Abstand + 56 CTA + 12 Luft). Bei geschlossener Tastatur wirkt er nicht.
 - Gescrollt wird nur, wenn das Feld (teilweise) verdeckt ist. Muster wie ReceiptReviewSheet: erst den neuen
   Sichtbereich abwarten (50 ms), dann `scrollTo`.
 - `.scrollIndicators` / `.scrollDismissesKeyboard` wirken von außen (Umgebungswerte).

 📝 Last Change:
 - Neu: gilt für alle Formular-Sheets mit schwebendem CTA.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// ScrollView, die das fokussierte Eingabefeld immer über Tastatur und schwebenden Knöpfen zeigt.
struct KeyboardRevealScrollView<Content: View>: View {
    /// Aktuelle Tastaturhöhe (0 = geschlossen).
    let keyboardHeight: CGFloat
    /// Um so viel endet der sichtbare Bereich bei offener Tastatur weiter oben.
    let bottomInset: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var focusedField: FocusedFieldFrame?
    @State private var viewportHeight: CGFloat = 0

    private var activeInset: CGFloat { keyboardHeight > 0 ? max(0, bottomInset) : 0 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { content() }
                .coordinateSpace(.named(FocusedFieldFrame.space))
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { viewportHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, height in viewportHeight = height }
                    }
                }
                .onPreferenceChange(FocusedFieldFrame.Key.self) { frame in
                    MainActor.assumeIsolated { focusedField = frame }         // Preferences kommen auf dem Main-Thread
                }
                .padding(.bottom, activeInset)
                .onChange(of: focusedField?.id) { _, _ in reveal(proxy) }
                .onChange(of: activeInset) { _, _ in reveal(proxy) }
        }
    }

    /// Holt das fokussierte Feld in den sichtbaren Bereich, falls es unten oder oben (teilweise) verdeckt ist.
    private func reveal(_ proxy: ScrollViewProxy) {
        guard keyboardHeight > 0, focusedField != nil else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))        // erst nach dem neuen Sichtbereich prüfen
            guard keyboardHeight > 0, let field = focusedField else { return }
            let anchor: UnitPoint
            if field.frame.maxY > viewportHeight {
                anchor = .bottom
            } else if field.frame.minY < 0 {
                anchor = .top
            } else {
                return
            }
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(field.id, anchor: anchor) }
        }
    }
}

#Preview("Formular mit Tastatur") {
    @Previewable @State var text = ""
    KeyboardRevealScrollView(keyboardHeight: 0, bottomInset: 0) {
        VStack(spacing: 20) {
            ForEach(0..<12) { i in
                TextField("Feld \(i)", text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(20)
    }
}
