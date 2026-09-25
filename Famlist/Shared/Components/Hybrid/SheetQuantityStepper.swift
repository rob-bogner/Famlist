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

/// Mengen-Stepper: 148 × 52, Pille, − (deaktiviert bei 1) · Zahl · + (Glas-Knopf).
struct SheetQuantityStepper: View {
    let k: SheetTheme
    @Binding var quantity: Int
    var range: ClosedRange<Int> = 1...999

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { change(by: -1) }) {
                SVGIcon(Icon.minus, size: 16, color: canDecrease ? k.icon : k.stepOffIcon, lineWidth: 2.6)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(k.stepOff))
            }
            .buttonStyle(.plain)
            .disabled(!canDecrease)
            .accessibilityLabel("Menge verringern")

            Spacer(minLength: 0)
            Text("\(quantity)")
                .font(AppFont.outfit(19, 600))
                .foregroundStyle(k.text)
                .contentTransition(.numericText())
            Spacer(minLength: 0)

            Button(action: { change(by: 1) }) {
                SVGIcon(Icon.plus, size: 16, color: .white, lineWidth: 2.6)
                    .frame(width: 40, height: 40)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.55)
                            .frame(height: 15)
                            .padding(.horizontal, 7)
                            .padding(.top, 2)
                    }
                    .clipShape(Circle())
                    .background(CSSBox(shape: Circle(), paint: k.stepPaint, shadows: k.stepShadow))
            }
            .buttonStyle(.plain)
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
