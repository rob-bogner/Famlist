/*
 ReceiptAutoToggle.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schalter „Auto“/„Manuell“ im Kamerabildschirm, rechts neben den Aufnahmen.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCaptureLive.dc.html. Pille 32 hoch, Padding links 10 / rechts 12, Abstand 7,
   Glas neutral dunkel (Verlauf wie gnd.pbg, Schatten gnd), Glanz oben: links/rechts 8, oben 2, Höhe 12, Radius 6.
   Punkt 10: an = Akzent hell gefüllt, aus = Ring Weiß 70 % 1,5. Text DM Sans 13/600 weiß.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptAutoToggle: View {
    @Binding var isOn: Bool
    var accent: Color

    private let tokens = GlassStyleTokens(style: .neutralDark, appearance: .dark,
                                          accent: AccentScale(Appearance.dark.defaultAccent, .dark))

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(isOn ? accent : Color.clear)
                    .overlay { if !isOn { Circle().strokeBorder(Color.rgba(255, 255, 255, 0.7), lineWidth: 1.5) } }
                    .frame(width: 10, height: 10)
                Text(isOn ? "Auto" : "Manuell")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(Color.white)
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background(alignment: .top) {
                RR(6)
                    .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, 0.28), 0), stop(.rgba(255, 255, 255, 0), 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 12)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
            }
            .clipShape(Capsule())
            .background(CSSBox(shape: Capsule(), paint: tokens.pillPaint, shadows: tokens.shadows))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Automatisch auslösen")
        .accessibilityValue(isOn ? "An" : "Aus")
        .accessibilityAddTraits(.isToggle)
    }
}

#Preview("Auto-Schalter", traits: .fixedLayout(width: 240, height: 80)) {
    @Previewable @State var on = true
    HStack(spacing: 16) {
        ReceiptAutoToggle(isOn: $on, accent: AccentScale(Appearance.dark.defaultAccent, .dark).light.color())
        ReceiptAutoToggle(isOn: .constant(false), accent: .white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hex("#121A1B"))
}

#Preview("Auto-Schalter – Dark", traits: .fixedLayout(width: 240, height: 80)) {
    @Previewable @State var on = false
    ReceiptAutoToggle(isOn: $on, accent: AccentScale(Appearance.dark.defaultAccent, .dark).light.color())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hex("#121A1B"))
        .preferredColorScheme(.dark)
}
