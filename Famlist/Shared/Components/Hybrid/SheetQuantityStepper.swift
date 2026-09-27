/*
 SheetQuantityStepper.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengen-Stepper der Hybrid-Sheets: 148 × 52, Pille, − · Zahl · + (Glas-Knöpfe).
 - Zahl antippen → direkt eintippen (Ziffernblock). ± springt je nach Einheit (QuantityPresets.step).

 🔰 Notes for Beginners:
 - Heißt im Design `QuantityStepper`. Der Name ist in Famlist schon belegt (ViewModifiers.swift),
   deshalb `SheetQuantityStepper`.
 - Grenzen 1…9999 (QuantityPresets.range); Gramm/Milliliter brauchen mehr als 999.
 - `isEditing` meldet dem Sheet, dass die Zahl bearbeitet wird (Schnellwahl-Leiste über dem Ziffernblock).

 📝 Last Change:
 - Zahl eintippbar, Schrittweite je Einheit, aktiver Zustand mit Akzent-Ring (Canvas „Menge eintippen“).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Mengen-Stepper: 148 × 52, Pille, − (Glas neutral) · Zahl (eintippbar) · + (Glas Akzent).
struct SheetQuantityStepper: View {
    let k: SheetTheme
    @Binding var quantity: Int
    /// Einheit (rawValue) – bestimmt die Schrittweite der ± -Knöpfe.
    var measure: String = ""
    /// true, solange die Zahl per Ziffernblock bearbeitet wird.
    var isEditing: Binding<Bool> = .constant(false)
    var range: ClosedRange<Int> = QuantityPresets.range

    @State private var text = ""
    @FocusState private var focused: Bool

    private var step: Int { QuantityPresets.step(for: measure) }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { change(up: false) }) {
                GlassOrb(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.minus, size: 40,
                         iconSize: 16, iconColor: canDecrease ? nil : k.stepOffIcon, lineWidth: 2.6)
                    .frame(width: 44, height: 44)             // Trefferfläche 44, Optik 40
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(-2)                                      // 44er-Trefferfläche ohne Layout-Versatz
            .disabled(!canDecrease)
            .accessibilityLabel("Menge verringern")

            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(AppFont.outfit(19, 600))
                .foregroundStyle(k.text)
                .tint(k.a.base.color())
                .focused($focused)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Menge")
                .onChange(of: text) { _, newValue in apply(newValue) }

            Button(action: { change(up: true) }) {
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
        .background(background)
        .revealsWhenFocused(focused)            // über Schnellwahl-Leiste und Ziffernblock halten
        .animation(.easeOut(duration: 0.15), value: focused)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(quantity)")
        .onAppear { text = String(quantity) }
        .onChange(of: quantity) { _, q in if Int(text) != q { text = String(q) } }
        .onChange(of: focused) { _, isFocused in
            isEditing.wrappedValue = isFocused
            if !isFocused { commit() }
        }
        .onChange(of: isEditing.wrappedValue) { _, editing in if !editing { focused = false } }
    }

    /// Ruhe: field + Rahmen 1. Bearbeiten: helle Fläche, Rand 1,5 ring, Ring 4 ringSoft (wie aktive Felder).
    @ViewBuilder
    private var background: some View {
        if focused {
            CSSBox(shape: Pill, paint: .color(k.isDark ? .rgba(255, 255, 255, 0.06) : .white), border: 1.5,
                   borderColor: k.ring, shadows: [.drop(0, 0, 0, 4, k.ringSoft)])
        } else {
            CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder)
        }
    }

    private var canDecrease: Bool { quantity > range.lowerBound }

    /// Nur Ziffern, höchstens 4 Stellen; gültige Werte sofort übernehmen (leer bleibt stehen bis zum Verlassen).
    private func apply(_ raw: String) {
        let digits = String(raw.filter(\.isNumber).prefix(4))
        if digits != raw { text = digits; return }
        if let v = Int(digits), range.contains(v), v != quantity { quantity = v }
    }

    private func commit() {
        let v = Int(text) ?? quantity
        quantity = min(max(v, range.lowerBound), range.upperBound)
        text = String(quantity)
    }

    private func change(up: Bool) {
        let next = QuantityPresets.next(quantity, up: up, step: step)
        guard next != quantity else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.snappy(duration: 0.2)) { quantity = next }
    }
}

#Preview {
    @Previewable @State var quantity = 500
    SheetQuantityStepper(k: SheetTheme(.light), quantity: $quantity, measure: "g")
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var quantity = 1
    SheetQuantityStepper(k: SheetTheme(.dark), quantity: $quantity)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
