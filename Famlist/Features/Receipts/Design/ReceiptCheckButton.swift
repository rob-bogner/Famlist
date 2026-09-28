/*
 ReceiptCheckButton.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Prüfen“-Pille mit Anzahl der Aufnahmen im Kamerabildschirm.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCapture.dc.html. Ohne Aufnahme gedimmt (45 %) und nicht tippbar.

 📝 Last Change:
 - Unverändert aus ReceiptCaptureView herausgelöst (Datei wurde zu lang).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptCheckButton: View {
    let count: Int
    let theme: SheetTheme
    var action: () -> Void

    private var k: SheetTheme { theme }

    /// „Prüfen“ + Anzahl: Pille 52 hoch, Padding 16/12, Abstand 8, Glanz oben; ohne Aufnahme Glas, 45 %.
    var body: some View {
        let enabled = count > 0
        return Button(action: action) {
            HStack(spacing: 8) {
                Text("Prüfen")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(enabled ? k.ctaText : Color.white)
                Text("\(count)")
                    .font(AppFont.dm(13, 700))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 6)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Capsule().fill(enabled ? Color.rgba(4, 38, 42, 0.85) : Color.rgba(255, 255, 255, 0.2)))
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(height: 52)
            .background {
                if enabled {
                    PillGlassReflection(topInset: 11, topOffset: 2, topHeight: 18, topOpacity: 0.4,
                                        glowInset: 22, glowOffset: 2, glowHeight: 6,
                                        glowOpacity: 0.14, glowBlur: 2.5)
                }
            }
            .clipShape(Capsule())
            .background(CSSBox(shape: Capsule(),
                               paint: enabled ? k.ctaPaint : .color(.rgba(255, 255, 255, 0.14)),
                               shadows: enabled ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                                   .drop(0, 10, 22, -10, k.a.base.color(0.8))] : []))
            .contentShape(Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.2), value: enabled)
        .accessibilityLabel(enabled ? (count == 1 ? "1 Aufnahme prüfen und Preise auslesen"
                                                  : "\(count) Aufnahmen prüfen und Preise auslesen")
                                    : "Prüfen – erst ein Foto aufnehmen")
    }
}

#Preview("Prüfen", traits: .fixedLayout(width: 260, height: 100)) {
    HStack(spacing: 16) {
        ReceiptCheckButton(count: 0, theme: SheetTheme(.dark)) {}
        ReceiptCheckButton(count: 2, theme: SheetTheme(.dark)) {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hex("#121A1B"))
}

#Preview("Prüfen – Dark", traits: .fixedLayout(width: 260, height: 100)) {
    ReceiptCheckButton(count: 3, theme: SheetTheme(.dark)) {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hex("#121A1B"))
        .preferredColorScheme(.dark)
}
