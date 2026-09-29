/*
 ProductDetailCard.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte in „Produktdetails“ (ProductDetail.dc.html): Icon 15 + Beschriftung (DM 13/600, sub),
   darunter der Wert. Padding 12 / 10 / 12 / 14, Radius 18, Abstand 8.

 🔰 Notes for Beginners:
 - `.info`: Ansehen (weiße Karte mit Schatten bzw. Glas-Verlauf im Dunkeln).
 - `.field`: Bearbeiten (Feldfläche mit Rand, wie Eingabefelder).
 - `.focused`: Menge wird gerade eingetippt (Rand 1,5 ring + Ring 4 ringSoft).

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Card with icon label and value, used in the product detail grid.
struct ProductDetailCard<Value: View>: View {
    enum Style { case info, field, focused }

    let k: SheetTheme
    let icon: [SVGElement]
    let label: String
    var style: Style = .info
    @ViewBuilder let value: () -> Value

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SVGIcon(icon, size: 15, color: k.accentText, lineWidth: 2)
                Text(label)
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            value()
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        }
        .padding(.top, 13)                      // 1 Rahmen + 12
        .padding(.bottom, 13)
        .padding(.leading, 15)                  // 1 Rahmen + 14
        .padding(.trailing, 11)                 // 1 Rahmen + 10
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .info:
            if k.isDark {
                CSSBox(shape: RR(18),
                       paint: .linear(180, [stop(.rgba(255, 255, 255, 0.07), 0), stop(.rgba(255, 255, 255, 0.03), 1)]),
                       border: 1, borderColor: .rgba(255, 255, 255, 0.08),
                       shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))])
            } else {
                CSSBox(shape: RR(18), paint: .color(.white), border: 1, borderColor: .hex("#EDF2F2"),
                       shadows: [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))])
            }
        case .field:
            CSSBox(shape: RR(18), paint: .color(k.field), border: 1, borderColor: k.fieldBorder)
        case .focused:
            CSSBox(shape: RR(18), paint: .color(k.fieldFocus), border: 1.5, borderColor: k.ring,
                   shadows: [.drop(0, 0, 0, 4, k.ringSoft)])
        }
    }
}
