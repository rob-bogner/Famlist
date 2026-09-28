/*
 ReceiptShutterButton.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Auslöser im Kamerabildschirm (80, Rand Weiß 90 % 4, Innenkreis 62) mit Fortschrittsring für Auto.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCapture.dc.html (Knopf) und ReceiptCaptureLive.dc.html (Ring). Der Ring liegt auf dem
   weißen Rand: Kreis r 38, Linie 4 in Akzent hell, runde Enden, beginnt oben und füllt sich im Uhrzeigersinn.
   Voll = die Kamera löst aus.

 📝 Last Change:
 - Initial creation (aus ReceiptCaptureView herausgelöst, Ring für Auto ergänzt).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptShutterButton: View {
    /// 0…1; nil = kein Ring.
    var progress: Double?
    var ringColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.white)
                .padding(9)
                .frame(width: 80, height: 80)
                .overlay(Circle().strokeBorder(Color.rgba(255, 255, 255, 0.9), lineWidth: 4))
                .overlay {
                    if let progress {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(2)                      // Mittellinie r 38 = auf dem weißen Rand
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Foto aufnehmen")
    }
}

#Preview("Auslöser", traits: .fixedLayout(width: 240, height: 120)) {
    HStack(spacing: 30) {
        ReceiptShutterButton(progress: nil, ringColor: .white) {}
        ReceiptShutterButton(progress: 0.6, ringColor: AccentScale(Appearance.dark.defaultAccent, .dark).light.color()) {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hex("#121A1B"))
}

#Preview("Auslöser – Dark", traits: .fixedLayout(width: 240, height: 120)) {
    ReceiptShutterButton(progress: 0.3, ringColor: AccentScale(Appearance.dark.defaultAccent, .dark).light.color()) {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hex("#121A1B"))
        .preferredColorScheme(.dark)
}
