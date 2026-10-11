/*
 InlineQuantityPill.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mengen-Pille in der Artikelkarte (Design: ListQuantityEdit): − · Zahl · + und die Einheit,
   aktive Feld-Optik (helle Fläche, Rand 1,5 ring, Ring 4 ringSoft). Entsteht aus dem Mengen-Chip.

 🔰 Notes for Beginners:
 - Nutzt den Stepper aus „Artikel bearbeiten“ (SheetQuantityStepper, kompakt): Tippen = feiner Schritt,
   Halten = grober Schritt, Zahl antippen = Ziffernblock.
 - Meldet ihren Bildschirm-Rahmen an InlineQuantityEditor (Tippen außerhalb schließt sie).

 📝 Last Change:
 - Initial creation (Wunsch Robert 12.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InlineQuantityPill: View {
    let t: ListTheme
    let item: ItemModel
    let editor: InlineQuantityEditor

    @State private var quantity: Double = 1
    @State private var typing = false

    private var unit: String {
        item.measure.isEmpty ? "" : Measure.fromExternal(item.measure).localizedName
    }

    var body: some View {
        let k = SheetTheme(t.appearance)
        HStack(spacing: 4) {
            SheetQuantityStepper(k: k, quantity: $quantity, measure: item.measure, isEditing: $typing, compact: true)
                .frame(width: 122)
            if !unit.isEmpty {
                Text(unit)
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.accentText)
                    .fixedSize()
                    .padding(.trailing, 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 3)
        .frame(height: 40)
        .background(CSSBox(shape: Pill, paint: .color(t.isDark ? .rgba(255, 255, 255, 0.08) : .white), border: 1.5,
                           borderColor: k.ring, shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { editor.pillFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, frame in editor.pillFrame = frame }
            }
        }
        .onAppear { quantity = item.units }
        .onChange(of: quantity) { _, q in if q != item.units { editor.change(item.id, to: q) } }
        .onChange(of: typing) { _, v in editor.isTyping = v }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Menge von \(item.name)\(unit.isEmpty ? "" : " in \(unit)")")
    }
}
