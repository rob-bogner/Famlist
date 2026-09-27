/*
 WatchItemScreen.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel (WatchItem.dc.html): Name + Kategorie-Chip, Mengen-Stepper (Digital Crown und −/+),
   Hinweis „Menge mit der Krone ändern“, CTA „Abhaken“.

 🔰 Notes for Beginners:
 - Die Krone ändert die Menge sofort in der Anzeige; gemeldet wird sie erst, wenn die Krone ruht
   (onIdle), damit nicht jede Raste eine eigene Änderung wird (WATCH_PLAN.md §5).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchItemScreen: View {
    var w = WatchTheme()
    let backTitle: String
    let name: String
    let category: String
    let unitName: String
    @State var units: Double
    /// Schrittweite von Krone und ± (QuantityPresets.step: g/ml 50, sonst 1).
    var step: Double = 1
    var onUnitsChanged: (Double) -> Void = { _ in }
    /// Rasterschritte der Krone; jeder Schritt wendet dieselbe Regel an wie ± (QuantityPresets.next).
    @State private var crownTicks: Double = 0
    var onCheck: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            header
            stepper
            Text("Menge mit der Krone ändern")
                .font(WatchFont.dm(11)).foregroundStyle(w.faint)
                .watchLineBox(WatchFont.dmLineHeight(11))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            checkButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .watchScreen(backTitle, contentTop: 40, w: w, onBack: onBack)
    }

    /// Name Outfit 22/600 (−0.01em, line-height 1.1) und Chip 12/600, padding 3 9; Abstand 6, padding 0 4.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(WatchFont.outfit(22)).tracking(-0.22)
                .watchLineBox(WatchFont.scaled(22) * 1.1)
                .accessibilityAddTraits(.isHeader)
            Text(category)
                .font(WatchFont.dm(12, 600)).foregroundStyle(w.accentText)
                .watchLineBox(WatchFont.dmLineHeight(12, 600))
                .padding(.vertical, 3).padding(.horizontal, 9)
                .background(Capsule().fill(w.chip))
        }
        .foregroundStyle(w.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// Stepper: 56 hoch, padding 0 6, Radius 18 (Karte ohne Innenlicht); Knöpfe 40 (weiß .12, Icon 16/2,6);
    /// Zahl Outfit 24/600 (line-height 1.05) accentText, Einheit DM 11 weiß .6.
    private var stepper: some View {
        HStack {
            stepButton(Icon.minus, label: "Weniger") { change(up: false) }
            Spacer()
            VStack(spacing: 0) {
                Text(QuantityFormat.format(units)).font(WatchFont.outfit(24)).foregroundStyle(w.accentText)
                    .watchLineBox(WatchFont.scaled(24) * 1.05)
                Text(unitName).font(WatchFont.dm(11)).foregroundStyle(w.sub)
                    .watchLineBox(WatchFont.dmLineHeight(11))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Menge \(QuantityFormat.format(units)) \(unitName)")
            .accessibilityAdjustableAction { direction in change(up: direction == .increment) }
            Spacer()
            stepButton(Icon.plus, label: "Mehr") { change(up: true) }
        }
        .padding(.horizontal, 7)                          // Rand 1 + padding 6 (CSS border-box)
        .frame(minHeight: 56)
        .background(WatchCardBackground(w: w, innerHighlight: false))
        .focusable()
        .digitalCrownRotation(detent: $crownTicks, from: -100_000, through: 100_000, by: 1, sensitivity: .low,
                              isContinuous: false, isHapticFeedbackEnabled: true, onIdle: { onUnitsChanged(units) })
        .onChange(of: crownTicks) { old, new in
            let ticks = Int((new - old).rounded())
            for _ in 0..<abs(ticks) { units = QuantityPresets.next(units, up: ticks > 0, step: step) }
        }
    }

    /// CTA „Abhaken“: 44 hoch, Radius 22, Verlauf light → accent, inset 0 1 0 weiß .5, Text #04262A 15/600,
    /// Haken 16/2,8, Abstand 6.
    private var checkButton: some View {
        Button(action: onCheck) {
            HStack(spacing: 6) {
                SVGIcon(Icon.check, size: 16, color: w.ctaText, lineWidth: 2.8)
                Text("Abhaken").font(WatchFont.dm(15, 600)).foregroundStyle(w.ctaText)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(CSSBox(shape: Capsule(), paint: w.cta, shadows: [.inner(0, 1, 0, 0, .white.opacity(0.5))]))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ icon: [SVGElement], label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SVGIcon(icon, size: 16, color: .white, lineWidth: 2.6)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Eine Stufe mehr/weniger (1,5 + 1 → 2; 120 g + 50 → 150 g; unter 1 senkt „−“ nicht weiter).
    private func change(up: Bool) {
        units = QuantityPresets.next(units, up: up, step: step)
        onUnitsChanged(units)
    }
}

#Preview("Artikel") {
    NavigationStack {
        WatchItemScreen(backTitle: "My List", name: "Butter", category: "Milchprodukte", unitName: "Packung", units: 1)
    }
}
