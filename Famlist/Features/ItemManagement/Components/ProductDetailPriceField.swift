/*
 ProductDetailPriceField.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Preisfeld in „Produktdetails“ an der Stelle des großen Preises: 124 × 44, Radius 12,
   Zahl rechtsbündig in Outfit 26/700 (accentText), dahinter „€“.

 🔰 Notes for Beginners:
 - Eingabe wie SheetPriceField: nur Ziffern und ein Trennzeichen; im Binding steht der Wert mit Punkt.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Inline price input of the product detail screen.
struct ProductDetailPriceField: View {
    let k: SheetTheme
    @Binding var price: String
    var hasError = false

    @State private var text = ""
    @FocusState private var focused: Bool
    private var separator: String { Locale.current.decimalSeparator ?? "," }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $text, prompt: Text("0\(separator)00").foregroundStyle(k.accentText.opacity(0.45)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(AppFont.outfit(26, 700))
                .foregroundStyle(k.accentText)
                .tint(k.accent)
                .focused($focused)
                .accessibilityLabel("Preis")                     // UI-Tests suchen „Preis“
                .onChange(of: text) { _, newValue in apply(newValue) }
            Text(Locale.current.currencySymbol ?? "€")
                .font(AppFont.outfit(26, 700))
                .foregroundStyle(k.accentText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 11)                  // 1 Rahmen + 10
        .frame(width: 124, height: 44)
        .background(CSSBox(shape: RR(12), paint: .color(focused ? k.fieldFocus : k.field),
                           border: focused ? 1.5 : 1,
                           borderColor: hasError ? .hex("#E5484D") : (focused ? k.ring : k.fieldBorder),
                           shadows: focused ? [.drop(0, 0, 0, 4, k.ringSoft)] : []))
        .revealsWhenFocused(focused)
        .onAppear { text = displayText(from: price) }
    }

    /// Keeps digits and one separator, then writes the dot-decimal value back to the binding.
    private func apply(_ raw: String) {
        var result = ""
        var hasSeparator = false
        for ch in raw {
            if ch.isNumber {
                result.append(ch)
            } else if (ch == "," || ch == ".") && !hasSeparator {
                hasSeparator = true
                result.append(contentsOf: separator)
            }
        }
        if result != raw { text = result }
        price = result.replacingOccurrences(of: separator, with: ".")
    }

    private func displayText(from stored: String) -> String {
        guard let value = Double(stored.replacingOccurrences(of: ",", with: ".")), value > 0 else { return "" }
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: separator)
    }
}
