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
 - Menge mit Nachkommastellen (z. B. 1,5 kg): eintippen 0,01…9999 (QuantityFormat.range), ± bleibt ab 1
   (QuantityPresets.range) und rastet auf die Schrittweite ein.
 - `isEditing` meldet dem Sheet, dass die Zahl bearbeitet wird (Schnellwahl-Leiste über dem Ziffernblock).

 📝 Last Change:
 - Kommazahlen: Komma-Tastatur, höchstens 4 Vor- und 2 Nachkommastellen, Anzeige „1,5“.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Mengen-Stepper: 148 × 52, Pille, − (Glas neutral) · Zahl (eintippbar) · + (Glas Akzent).
struct SheetQuantityStepper: View {
    let k: SheetTheme
    @Binding var quantity: Double
    /// Einheit (rawValue) – bestimmt die Schrittweite der ± -Knöpfe.
    var measure: String = ""
    /// true, solange die Zahl per Ziffernblock bearbeitet wird.
    var isEditing: Binding<Bool> = .constant(false)
    var range: ClosedRange<Double> = QuantityFormat.range
    /// Kompakt (Karte „Menge“ in Produktdetails): Knöpfe 32, Zahl Outfit 18, ohne eigene Fläche, volle Breite.
    var compact = false

    @State private var text = ""
    @FocusState private var focused: Bool

    /// Tippen: feiner Schritt (0,1 kg); gedrückt halten: grober Schritt (1 kg) – Wunsch Robert 27.09.2026.
    private var step: Double { QuantityPresets.step(for: measure) }
    private var coarseStep: Double { QuantityPresets.coarseStep(for: measure) }

    var body: some View {
        HStack(spacing: 0) {
            HoldRepeatButton(onTap: { change(up: false, step: step) }, onRepeat: { change(up: false, step: coarseStep) }) {
                GlassOrb(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.minus, size: orbSize,
                         iconSize: compact ? 14 : 16, iconColor: canDecrease ? nil : k.stepOffIcon, lineWidth: 2.6)
                    .frame(width: 44, height: 44)             // Trefferfläche 44, Optik 40
                    .contentShape(Circle())
            }
            .padding(-(44 - orbSize) / 2)                     // 44er-Trefferfläche ohne Layout-Versatz
            .disabled(!canDecrease)
            .accessibilityLabel("Menge verringern")

            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(AppFont.outfit(compact ? 18 : 19, 600))
                .foregroundStyle(k.text)
                .tint(k.a.base.color())
                .focused($focused)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Menge")
                .onChange(of: text) { _, newValue in apply(newValue) }

            HoldRepeatButton(onTap: { change(up: true, step: step) }, onRepeat: { change(up: true, step: coarseStep) }) {
                GlassOrb(style: .accent, appearance: k.appearance, accent: k.a, icon: Icon.plus, size: orbSize,
                         iconSize: compact ? 14 : 16, lineWidth: 2.6)
                    .frame(width: 44, height: 44)             // Trefferfläche 44, Optik 40
                    .contentShape(Circle())
            }
            .padding(-(44 - orbSize) / 2)                     // 44er-Trefferfläche ohne Layout-Versatz
            .disabled(quantity >= range.upperBound)
            .accessibilityLabel("Menge erhöhen")
        }
        .padding(.horizontal, compact ? 0 : 6)          // 1 border + 5 padding
        .frame(width: compact ? nil : 148, height: compact ? 36 : 52)
        .frame(maxWidth: compact ? .infinity : nil)
        .background { if !compact { background } }
        .revealsWhenFocused(focused)            // über Schnellwahl-Leiste und Ziffernblock halten
        .animation(.easeOut(duration: 0.15), value: focused)
        .accessibilityElement(children: .contain)
        .accessibilityValue(QuantityFormat.format(quantity))
        .onAppear { text = QuantityFormat.format(quantity) }
        .onChange(of: quantity) { _, q in if QuantityFormat.parse(text) != q { text = QuantityFormat.format(q) } }
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

    private var orbSize: CGFloat { compact ? 32 : 40 }

    private var canDecrease: Bool { quantity > QuantityPresets.minimum(forStep: step) }

    /// Nur Ziffern und ein Komma (höchstens 4 + 2 Stellen); gültige Werte sofort übernehmen
    /// (leer oder „1,“ bleibt stehen bis zum Verlassen).
    private func apply(_ raw: String) {
        let clean = QuantityFormat.sanitizeInput(raw)
        if clean != raw { text = clean; return }
        if let v = QuantityFormat.parse(clean), range.contains(v), v != quantity { quantity = v }
    }

    private func commit() {
        let v = QuantityFormat.parse(text) ?? quantity
        quantity = min(max(v, range.lowerBound), range.upperBound)
        text = QuantityFormat.format(quantity)
    }

    private func change(up: Bool, step: Double) {
        let next = QuantityPresets.next(quantity, up: up, step: step)
        guard next != quantity else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.snappy(duration: 0.2)) { quantity = next }
    }
}

#Preview {
    @Previewable @State var quantity: Double = 500
    SheetQuantityStepper(k: SheetTheme(.light), quantity: $quantity, measure: "g")
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var quantity: Double = 1.5
    SheetQuantityStepper(k: SheetTheme(.dark), quantity: $quantity)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
