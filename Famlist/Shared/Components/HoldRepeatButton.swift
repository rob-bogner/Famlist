/*
 HoldRepeatButton.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Knopf für ± an Mengen: kurz tippen → `onTap` (feiner Schritt), gedrückt halten → nach `holdDelay`
   wiederholt `onRepeat` (grober Schritt) mit `interval` Pause.

 🔰 Notes for Beginners:
 - Wunsch Robert (27.09.2026): einzeln tippen = 0,1 kg; Finger drauf lassen = 1er-Schritte mit genug Pause,
   damit man ohne Probleme auf dem gewünschten Wert loslassen kann (0,7 s).
 - iPhone (SheetQuantityStepper) und Uhr (WatchItemScreen) nutzen denselben Knopf
   (Uhr: scripts/watch_shared_sources.txt).
 - VoiceOver: Die Standard-Aktion entspricht einem kurzen Tippen.

 📝 Last Change:
 - Neu.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct HoldRepeatButton<Label: View>: View {
    /// So lange muss der Finger liegen, bevor die Wiederholung startet.
    var holdDelay: Duration = .milliseconds(500)
    /// Pause zwischen zwei Wiederholungen.
    var interval: Duration = .milliseconds(700)
    let onTap: () -> Void
    let onRepeat: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var task: Task<Void, Never>?
    @State private var repeated = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in start() }
                .onEnded { _ in stop() })
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if isEnabled { onTap() } }
            .onDisappear { task?.cancel(); task = nil }
    }

    private func start() {
        guard task == nil, isEnabled else { return }
        repeated = false
        task = Task { @MainActor in
            try? await Task.sleep(for: holdDelay)
            while !Task.isCancelled {
                repeated = true
                onRepeat()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func stop() {
        guard let running = task else { return }
        running.cancel()
        task = nil
        if !repeated { onTap() }
    }
}

#Preview {
    @Previewable @State var value = 1.5
    VStack(spacing: 16) {
        Text(QuantityFormat.format(value)).font(.title)
        HoldRepeatButton(onTap: { value += 0.1 }, onRepeat: { value += 1 }) {
            Text("+").font(.largeTitle)
        }
    }
    .padding()
}
