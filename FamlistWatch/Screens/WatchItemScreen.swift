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
    /// Aktueller Stand aus dem Sync (z. B. am iPhone geändert) – übernimmt der offene Screen sofort.
    var remoteUnits: Double?
    /// Feiner Schritt (± tippen, Krone langsam) und grober Schritt (± halten, Krone schnell), QuantityPresets.
    var step: Double = 1
    var coarseStep: Double = 1
    var onUnitsChanged: (Double) -> Void = { _ in }
    /// Rasterschritte der Krone; jeder Schritt wendet dieselbe Regel an wie ± (QuantityPresets.next).
    @State private var crownTicks: Double = 0
    /// Zeitpunkt der letzten Raste – daraus die eigene Geschwindigkeitsmessung.
    @State private var lastTickTime: Date?
    /// Folgt eine Raste schneller als 200 ms auf die vorige, gilt das Drehen als schnell. Gemessen am 27.09.2026
    /// auf der Apple Watch Ultra: schnell (eine Umdrehung = 6 Rasten) 73–141 ms, langsam 384–1035 ms.
    /// `DigitalCrownEvent.velocity` ist dafür unbrauchbar: während der Bewegung fast immer 0, erst beim Einrasten ein Wert.
    private static let fastTickInterval: TimeInterval = 0.2
    /// Langsam gedreht zählt jede 2. Raste als feiner Schritt. Stand 27.09.2026 (Robert: „einen Tick zu langsam“;
    /// 1 Raste war zu empfindlich). `.low` liefert nur ~6 Rasten pro Umdrehung – feiner geht es erst mit
    /// höherer Kronen-Empfindlichkeit (offen, siehe Handoff).
    private static let ticksPerFineStep = 2
    /// Schnell gedreht zählt erst jede 2. Raste als grober Schritt – sonst schießt die Menge übers Ziel
    /// (Robert, 27.09.: „keine Chance auf eine Punktlandung von 1,5 auf 3 kg“).
    private static let ticksPerCoarseStep = 2
    /// Gesammelte Rasten (mit Vorzeichen) bis zum nächsten Schritt – je Modus getrennt.
    @State private var fastTicks = 0
    @State private var slowTicks = 0
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
            stepButton(Icon.minus, label: "Weniger", up: false)
            Spacer()
            VStack(spacing: 0) {
                Text(QuantityFormat.format(units)).font(WatchFont.outfit(24)).foregroundStyle(w.accentText)
                    .watchLineBox(WatchFont.scaled(24) * 1.05)
                Text(unitName).font(WatchFont.dm(11)).foregroundStyle(w.sub)
                    .watchLineBox(WatchFont.dmLineHeight(11))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Menge \(QuantityFormat.format(units)) \(unitName)")
            .accessibilityAdjustableAction { direction in change(up: direction == .increment, step: step) }
            Spacer()
            stepButton(Icon.plus, label: "Mehr", up: true)
        }
        .padding(.horizontal, 7)                          // Rand 1 + padding 6 (CSS border-box)
        .frame(minHeight: 56)
        .background(WatchCardBackground(w: w, innerHighlight: false))
        .focusable()
        .digitalCrownRotation(detent: $crownTicks, from: -100_000, through: 100_000, by: 1, sensitivity: .low,
                              isContinuous: false, isHapticFeedbackEnabled: true,
                              onIdle: { onUnitsChanged(units) })
        .onChange(of: crownTicks) { old, new in
            let ticks = Int((new - old).rounded())
            let now = Date()
            let fast = lastTickTime.map { now.timeIntervalSince($0) < Self.fastTickInterval } ?? false
            lastTickTime = now
            applyCrown(ticks: ticks, fast: fast)
        }
        .onChange(of: remoteUnits) { _, remote in
            if let remote, remote != units { units = remote }
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

    /// ± : tippen = feiner Schritt, gedrückt halten = grober Schritt mit Pause (HoldRepeatButton).
    private func stepButton(_ icon: [SVGElement], label: String, up: Bool) -> some View {
        HoldRepeatButton(onTap: { change(up: up, step: step) }, onRepeat: { change(up: up, step: coarseStep) }) {
            SVGIcon(icon, size: 16, color: .white, lineWidth: 2.6)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }

    /// Krone: langsam je 2 Rasten ein feiner Schritt (0,1 kg); schnell je 2 Rasten ein grober Schritt (1 kg).
    /// Richtungs- oder Moduswechsel setzt die gesammelten Rasten zurück.
    private func applyCrown(ticks: Int, fast: Bool) {
        guard ticks != 0 else { return }
        if fast && coarseStep != step {
            slowTicks = 0
            units = accumulate(&fastTicks, ticks: ticks, per: Self.ticksPerCoarseStep, step: coarseStep)
        } else {
            fastTicks = 0
            units = accumulate(&slowTicks, ticks: ticks, per: Self.ticksPerFineStep, step: step)
        }
    }

    /// Sammelt Rasten und wendet je `per` Rasten einen Schritt an; gibt die neue Menge zurück.
    private func accumulate(_ counter: inout Int, ticks: Int, per: Int, step: Double) -> Double {
        if counter != 0 && (counter > 0) != (ticks > 0) { counter = 0 }
        counter += ticks
        var value = units
        while abs(counter) >= per {
            value = QuantityPresets.next(value, up: counter > 0, step: step)
            counter -= counter > 0 ? per : -per
        }
        return value
    }

    /// Eine Stufe mehr/weniger (1,5 + 0,1 → 1,6; 1,5 + 1 → 2; 120 g + 50 → 150 g).
    private func change(up: Bool, step: Double) {
        units = QuantityPresets.next(units, up: up, step: step)
        onUnitsChanged(units)
    }
}

#Preview("Artikel") {
    NavigationStack {
        WatchItemScreen(backTitle: "My List", name: "Butter", category: "Milchprodukte", unitName: "Packung", units: 1)
    }
}
