/*
 CheckGestureSettingRow.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeile „Artikel abhaken“ in den Einstellungen (Settings.dc.html, Abschnitt „Liste“).

 🔰 Notes for Beginners:
 - Padding 12 / 14 / 14, Linie oben (k.line), Titel 15/500, Unterzeile 12 sub (erklärt die Wahl), Abstand 10.
 - Segment: Hintergrund segBg, Padding 3, Radius 13, 3 gleiche Spalten, Abstand 3; Knopf 36 hoch, Radius 10,
   aktiv segOn mit Schatten, Text 14/600 (aktiv) bzw. 14/500 sub.

 📝 Last Change:
 - Initial creation (Einstellung „Artikel abhaken“).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Settings row with a three-way segment for how items are checked off.
struct CheckGestureSettingRow: View {
    let t: ListAccountTokens
    @Binding var raw: String

    private var selection: CheckGesture { CheckGesture.from(raw) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Artikel abhaken")
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(t.k.text)
                Text(selection.hint)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(t.k.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 3) {
                ForEach(CheckGesture.allCases) { option in
                    segment(option)
                }
            }
            .padding(3)
            .background(RR(13).fill(t.segBg))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Artikel abhaken")
        }
        .padding(.top, 13)                                   // 12 + 1 Linie
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(t.line).frame(height: 1)
        }
    }

    private func segment(_ option: CheckGesture) -> some View {
        let isOn = option == selection
        return Button(action: { raw = option.rawValue }) {
            Text(option.label)
                .font(AppFont.dm(14, isOn ? 600 : 500))
                .foregroundStyle(isOn ? t.segOnText : t.k.sub)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if isOn {
                        CSSBox(shape: RR(10), paint: .color(t.segOn), shadows: [.drop(0, 1, 3, 0, .rgba(0, 0, 0, 0.12))])
                    }
                }
                .contentShape(RR(10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var raw = CheckGesture.both.rawValue
    CheckGestureSettingRow(t: ListAccountTokens(.light), raw: $raw)
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var raw = CheckGesture.swipe.rawValue
    CheckGestureSettingRow(t: ListAccountTokens(.dark), raw: $raw)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
