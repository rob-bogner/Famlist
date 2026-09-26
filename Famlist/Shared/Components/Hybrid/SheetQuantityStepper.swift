/*
 SheetQuantityStepper.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengen-Stepper der Hybrid-Sheets: 148 × 52, Pille, − (deaktiviert bei 1) · Zahl · + (Glas-Knopf).

 🔰 Notes for Beginners:
 - Heißt im Design `QuantityStepper`. Der Name ist in Famlist schon belegt (ViewModifiers.swift),
   deshalb `SheetQuantityStepper`.
 - Obergrenze 999 wie im bisherigen QuantityMeasureRow.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen (umbenannt, Obergrenze + Haptik ergänzt).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Mengen-Stepper: 148 × 52, Pille, − (Glas neutral, deaktiviert bei 1) · Zahl · + (Glas Akzent).
struct SheetQuantityStepper: View {
    let k: SheetTheme
    @Binding var quantity: Int
    var range: ClosedRange<Int> = 1...999

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { change(by: -1) }) {
                GlassOrb(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.minus, size: 40,
                         iconSize: 16, iconColor: canDecrease ? nil : k.stepOffIcon, lineWidth: 2.6)
                    .frame(width: 44, height: 44)             // Trefferfläche 44, Optik 40
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(-2)                                      // 44er-Trefferfläche ohne Layout-Versatz
            .disabled(!canDecrease)
            .accessibilityLabel("Menge verringern")

            Spacer(minLength: 0)
            Text("\(quantity)")
                .font(AppFont.outfit(19, 600))
                .foregroundStyle(k.text)
                .contentTransition(.numericText())
            Spacer(minLength: 0)

            Button(action: { change(by: 1) }) {
                GlassOrb(style: .accent, appearance: k.appearance, accent: k.a, icon: Icon.plus, size: 40,
                         iconSize: 16, lineWidth: 2.6)
                    .frame(width: 44, height: 44)             // Trefferfläche 44, Optik 40
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(-2)                                      // 44er-Trefferfläche ohne Layout-Versatz
            .disabled(quantity >= range.upperBound)
            .accessibilityLabel("Menge erhöhen")
        }
        .padding(.horizontal, 6)                        // 1 border + 5 padding
        .frame(width: 148, height: 52)
        .background(CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(quantity)")
    }

    private var canDecrease: Bool { quantity > range.lowerBound }

    private func change(by delta: Int) {
        let next = min(max(quantity + delta, range.lowerBound), range.upperBound)
        guard next != quantity else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.snappy(duration: 0.2)) { quantity = next }
    }
}

#Preview {
    @Previewable @State var quantity = 1
    SheetQuantityStepper(k: SheetTheme(.light), quantity: $quantity)
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var quantity = 1
    SheetQuantityStepper(k: SheetTheme(.dark), quantity: $quantity)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
