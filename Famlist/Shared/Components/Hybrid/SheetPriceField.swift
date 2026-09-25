/*
 SheetPriceField.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Preisfeld der Sheet „Artikel bearbeiten“: 148 × 52, Radius 16, Währungssymbol rechts.

 🔰 Notes for Beginners:
 - Übernimmt die Regel des bisherigen PriceField: gespeichert wird immer ein Punkt-Dezimalwert
   ("1.99"), angezeigt und eingegeben wird mit dem Dezimaltrenner des Geräts ("1,99").
 - Erlaubt sind nur Ziffern und ein einziger Trenner. Komma und Punkt werden beide akzeptiert.
 - Preis 0 zeigt den Platzhalter „0,00“ statt einer 0.

 📝 Last Change:
 - Initial creation (aus dem Preisfeld des Designs abgeleitet).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Locale-aware price input in Hybrid style. Binding holds a dot-decimal string.
struct SheetPriceField: View {
    let k: SheetTheme
    @Binding var price: String
    var hasError = false

    @State private var text = ""
    private var separator: String { Locale.current.decimalSeparator ?? "," }

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text("0\(separator)00").foregroundStyle(k.sub.opacity(0.75)))
                .keyboardType(.decimalPad)
                .font(AppFont.dm(16, 500))
                .foregroundStyle(k.text)
                .tint(k.accent)
                .accessibilityLabel("Preis")
                .onChange(of: text) { _, newValue in apply(newValue) }
            Text(Locale.current.currencySymbol ?? "€")
                .font(AppFont.dm(16, 600))
                .foregroundStyle(k.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 17)                // 1 border + 16 padding
        .frame(width: 148, height: 52)
        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1,
                           borderColor: hasError ? .hex("#E5484D") : k.fieldBorder))
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
        var raw = String(value)
        if raw.hasSuffix(".0") { raw.removeLast(2) }
        return raw.replacingOccurrences(of: ".", with: separator)
    }
}

#Preview {
    @Previewable @State var price = "1.99"
    SheetPriceField(k: SheetTheme(.light), price: $price)
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var price = "1.99"
    SheetPriceField(k: SheetTheme(.dark), price: $price)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
