/*
 EKKInputField.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einfaches Eingabefeld (Rahmen innen, Platzhalter 75 %).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Einfaches Eingabefeld (Platzhalter = Textfarbe mit 75 % Deckkraft).
/// Rahmen 1 liegt innen (box-sizing: border-box) → Einzug = 1 + padding.
struct EKKInputField: View {
    let k: SheetTheme
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    let radius: CGFloat
    let horizontalPadding: CGFloat
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(k.sub.opacity(0.75)))
            .keyboardType(keyboard)
            .font(AppFont.dm(16, 400))
            .foregroundStyle(k.sub)
            .tint(k.accent)
            .padding(.horizontal, horizontalPadding + 1)
            .frame(height: height)
            .background(CSSBox(shape: RR(radius), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .accessibilityLabel(placeholder)
    }
}

#Preview("EKKInputField") {
    @Previewable @State var text = ""
    EKKInputField(k: SheetTheme(.light), text: $text, placeholder: "E-Mail-Adresse",
                  height: 52, radius: 14, horizontalPadding: 16, keyboard: .emailAddress)
        .padding(20)
}

#Preview("EKKInputField – Dark") {
    @Previewable @State var text = ""
    EKKInputField(k: SheetTheme(.dark), text: $text, placeholder: "E-Mail-Adresse",
                  height: 52, radius: 14, horizontalPadding: 16, keyboard: .emailAddress)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
