//  ProductImageScreen.swift
//  MyListUI
//
//  Sheet „Produktbild“ – Höhe 452, unten bündig.
//  Innenabstand: oben 10, seitlich 20, unten 34. Inhalt horizontal zentriert.
//    Griff 5 → 12 → Titelzeile 44 → 22 → Bild 220×220 (Radius 40) → 22 → Name 26/600 → 8 → Mengen-Chip

import SwiftUI

struct ProductImageScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var productName = "Butter"
    var quantityText = "1 Packung"
    var onClose: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let dark = k.isDark
        let a = k.a

        // Bild-Platzhalter (bildschirmspezifische Werte aus dem Design)
        let thumbPaint: Paint = dark
            ? .linear(150, [stop(a.base.color(0.24), 0), stop(a.base.color(0.06), 1)])
            : .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)])
        let thumbShadows: [BoxShadow] = dark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.14)),
               .drop(0, 24, 40, -18, .rgba(0, 0, 0, 0.8))]
            : [.inner(0, 1, 0, 0, .white),
               .inner(0, -8, 18, 0, .rgba(12, 40, 44, 0.06)),
               .drop(0, 24, 40, -20, .rgba(12, 40, 44, 0.35))]
        let thumbIcon: Color = dark ? a.light.color() : .hex("#8AA0A4")
        let accentSoft = a.base.color(dark ? 0.16 : 0.1)
        let accentLine = a.base.color(dark ? 0.3 : 0.16)

        return SheetScreen(appearance: appearance, accentHex: accentHex) {
            SheetSurface(k: k, height: 452) {
                VStack(spacing: 0) {
                    SheetHeader(title: "Produktbild", k: k, onClose: onClose)

                    SVGIcon(Icon.cameraOff, size: 64, color: thumbIcon, lineWidth: 1.4)
                        .frame(width: 220, height: 220)
                        .background(alignment: .topLeading) {
                            // left -40, top -60, 220×160, radial-gradient(closest-side, rgba(255,255,255,.55), transparent)
                            CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                                              stops: [stop(.rgba(255, 255, 255, 0.55), 0), stop(.rgba(255, 255, 255, 0), 1)])
                                .frame(width: 220, height: 160)
                                .offset(x: -40, y: -60)
                        }
                        .clipShape(RR(40))
                        .background(CSSBox(shape: RR(40), paint: thumbPaint, shadows: thumbShadows))
                        .padding(.top, 22)
                        .accessibilityLabel("Kein Produktbild vorhanden")

                    VStack(spacing: 8) {
                        Text(productName)
                            .font(AppFont.outfit(26, 600))
                            .tracking(-0.26)                         // -0.01em × 26
                            .foregroundStyle(k.text)
                        Text(quantityText)
                            .font(AppFont.dm(13, 600))
                            .foregroundStyle(k.accentText)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 12)
                            .background(CSSBox(shape: Pill, paint: .color(accentSoft),
                                               shadows: [.inner(0, 0, 0, 1, accentLine)]))
                    }
                    .padding(.top, 22)

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
    }
}
