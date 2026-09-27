/*
 QuantityPresetBar.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Leiste direkt über dem Ziffernblock, solange die Menge bearbeitet wird (Canvas „Menge eintippen“):
   Schnellwahl passend zur Einheit als Glas-Chips, rechts „Fertig“.

 🔰 Notes for Beginners:
 - 50 hoch, volle Breite, Innenabstand 12, Fläche #F4F6F7 / #1F2426, oben Linie 1.
 - Chips 34 (GlassPillBackground): passender Wert Akzent mit weißer Schrift, sonst neutral mit Akzenttext.
 - „1 kg“ bzw. „1 l“ wechseln auch die Einheit.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct QuantityPresetBar: View {
    /// Höhe der Leiste; die Sheets halten die Mengenzeile um diesen Betrag über dem Ziffernblock.
    static let height: CGFloat = 50

    let k: SheetTheme
    let units: Int
    let measure: String
    var onSelect: (QuantityPreset) -> Void = { _ in }
    var onDone: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            ForEach(QuantityPresets.presets(for: measure)) { preset in
                let on = preset.units == units && Measure.fromExternal(preset.measure) == Measure.fromExternal(measure)
                Button(action: { onSelect(preset) }) {
                    Text(preset.label)
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(on ? .white : k.accentText)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(GlassPillBackground(style: on ? .accent : .neutral, appearance: k.appearance,
                                                        accent: k.a, height: 34))
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
            Button(action: onDone) {
                Text("Fertig")
                    .font(AppFont.dm(16, 600))
                    .foregroundStyle(k.accentText)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            (k.isDark ? Color.hex("#1F2426") : Color.hex("#F4F6F7"))
                .overlay(alignment: .top) {
                    Rectangle().fill(k.isDark ? Color.rgba(255, 255, 255, 0.06) : Color.rgba(0, 0, 0, 0.08)).frame(height: 1)
                }
        }
    }
}

#Preview("Schnellwahl") {
    QuantityPresetBar(k: SheetTheme(.light), units: 500, measure: "g")
}

#Preview("Schnellwahl – Dark") {
    QuantityPresetBar(k: SheetTheme(.dark), units: 500, measure: "g")
}
