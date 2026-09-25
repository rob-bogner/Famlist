/*
 SheetTextField.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eingabefeld der Hybrid-Sheets, Radius 16, Innenabstand 16.
   Ruhend: Hintergrund field, Rahmen 1. Fokussiert: weiß, Rahmen 1,5 in Akzent + 4-pt-Ring.

 🔰 Notes for Beginners:
 - Vereint `PlainField` (Bearbeiten, Höhe 48) und das fokussierte Namensfeld (Neuer Artikel, Höhe 52)
   aus dem Design. Der Fokus-Look folgt dem echten Tastaturfokus statt fest eingestellt zu sein.
 - Platzhalter = Textfarbe mit 75 % Deckkraft (`input::placeholder { color: inherit; opacity: .75 }`).
 - `error` färbt den Rahmen rot und zeigt die Meldung darunter (Famlist-Ergänzung für die Validierung).

 📝 Last Change:
 - Initial creation (aus PlainField / Name-Feld des Designs abgeleitet).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid-Eingabefeld mit Fokus-Ring und optionaler Fehlermeldung.
struct SheetTextField: View {
    let k: SheetTheme
    @Binding var text: String
    let placeholder: String
    var height: CGFloat = 48
    var weight: CGFloat = 500
    var isSecondary = false
    var error: String? = nil
    /// Fokussiert das Feld nach der Einblend-Animation des Sheets (Neuer Artikel: Name).
    var autoFocus = false

    @FocusState private var isFocused: Bool

    private var textColor: Color { isSecondary ? k.sub : k.text }
    private let errorColor = Color.hex("#E5484D")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(textColor.opacity(0.75)))
                .font(AppFont.dm(16, weight))
                .foregroundStyle(textColor)
                .tint(k.accent)
                .focused($isFocused)
                .padding(.horizontal, isFocused ? 17.5 : 17)    // Rahmen + 16 padding
                .frame(height: height)
                .background(background)
                .accessibilityLabel(placeholder)
                .task {
                    guard autoFocus else { return }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    isFocused = true
                }
            if let error {
                Text(error)
                    .font(AppFont.dm(12, 500))
                    .foregroundStyle(errorColor)
                    .padding(.leading, 4)
            }
        }
    }

    private var background: some View {
        let border = error != nil ? errorColor : (isFocused ? k.ring : k.fieldBorder)
        return CSSBox(shape: RR(16),
                      paint: .color(isFocused ? k.fieldFocus : k.field),
                      border: isFocused ? 1.5 : 1,
                      borderColor: border,
                      shadows: isFocused ? [.drop(0, 0, 0, 4, k.ringSoft)] : [])
    }
}

#Preview {
    @Previewable @State var name = "Butter"
    @Previewable @State var brand = ""
    VStack(spacing: 8) {
        SheetTextField(k: SheetTheme(.light), text: $name, placeholder: "Name", height: 52)
        SheetTextField(k: SheetTheme(.light), text: $brand, placeholder: "Marke", weight: 400, isSecondary: true)
        SheetTextField(k: SheetTheme(.light), text: .constant(""), placeholder: "Name", error: "Bitte einen Namen eingeben")
    }
    .padding(20)
}

#Preview("Dark") {
    @Previewable @State var name = "Butter"
    @Previewable @State var brand = ""
    VStack(spacing: 8) {
        SheetTextField(k: SheetTheme(.dark), text: $name, placeholder: "Name", height: 52)
        SheetTextField(k: SheetTheme(.dark), text: $brand, placeholder: "Marke", weight: 400, isSecondary: true)
        SheetTextField(k: SheetTheme(.dark), text: .constant(""), placeholder: "Name", error: "Bitte einen Namen eingeben")
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
