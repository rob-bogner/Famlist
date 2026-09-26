/*
 ListAccountFocusedField.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fokussiertes Textfeld 52 hoch mit Ring (Neue Liste, Profil).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Fokussiertes Textfeld: 52 hoch, Radius 16, Rahmen 1,5 ring, 4-pt-Ring ringSoft, padding 0 16, gap 2.
/// `leading` ist das Element vor dem Eingabefeld (Design-Cursor bzw. „@“).
struct ListAccountFocusedField<Leading: View>: View {
    let t: ListAccountTokens
    @Binding var text: String
    let placeholder: String
    let a11yLabel: String
    /// App: Feld beim Erscheinen fokussieren (nach der Einblend-Animation).
    var autoFocus = false
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}
    @ViewBuilder let leading: () -> Leading
    @FocusState private var focused: Bool

    var body: some View {
        let k = t.k
        HStack(spacing: 2) {
            leading()
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(t.placeholderOnText))
                .font(AppFont.dm(16, 400))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .accessibilityLabel(a11yLabel)
                .focused($focused)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 17.5)                          // 1,5 Rahmen + 16 Padding
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                           shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
        .task {
            guard autoFocus else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            focused = true
        }
    }
}

#Preview("ListAccountFocusedField") {
    @Previewable @State var text = "Wocheneinkauf"
    ListAccountFocusedField(t: ListAccountTokens(.light), text: $text, placeholder: "Listenname",
                            a11yLabel: "Listenname") {
        EmptyView()
    }
    .padding(20)
}

#Preview("ListAccountFocusedField – Dark") {
    @Previewable @State var text = "Wocheneinkauf"
    ListAccountFocusedField(t: ListAccountTokens(.dark), text: $text, placeholder: "Listenname",
                            a11yLabel: "Listenname") {
        EmptyView()
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
