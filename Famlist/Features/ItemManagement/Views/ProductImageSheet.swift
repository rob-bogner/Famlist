/*
 ProductImageSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Produktbild“ (Höhe 452). Ersetzt ProductImageFullscreenView.
   Titelzeile → 22 → Bild 220 × 220 (Radius 40) → 22 → Name Outfit 26/600 → 8 → Mengen-Chip.

 🔰 Notes for Beginners:
 - Ohne Foto zeigt die Kachel das durchgestrichene Kamera-Icon 64 wie im Design.
 - Marke und Beschreibung (bisher im Vollbild sichtbar) stehen in einer Zeile unter dem Chip.
   Dann wächst das Sheet um 28 pt. Das Design zeigt diese Zeile nicht.

 📝 Last Change:
 - Initial creation (aus ProductImageScreen des Design-Pakets MyListUI).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid product image sheet.
struct ProductImageSheet: View {
    let item: ItemModel
    let k: SheetTheme
    let maxHeight: CGFloat
    let onClose: () -> Void

    private var details: String {
        [item.brand, item.productDescription].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HybridSheetLayer(k: k, title: "Produktbild", designHeight: details.isEmpty ? 452 : 480,
                         maxHeight: maxHeight, onClose: onClose) {
            VStack(spacing: 0) {
                ProductImageTile(k: k, image: item.image)
                    .padding(.top, 22)
                    .accessibilityLabel(item.image == nil ? "Kein Produktbild vorhanden" : "Produktbild von \(item.name)")

                VStack(spacing: 8) {
                    Text(item.name)
                        .font(AppFont.outfit(26, 600))
                        .tracking(-0.26)                         // -0.01em × 26
                        .foregroundStyle(k.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(item.quantityText)
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(k.accentText)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .background(CSSBox(shape: Pill, paint: .color(k.a.base.color(k.isDark ? 0.16 : 0.1)),
                                           shadows: [.inner(0, 0, 0, 1, k.a.base.color(k.isDark ? 0.3 : 0.16))]))
                    if !details.isEmpty {
                        Text(details)
                            .font(AppFont.dm(14, 500))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 22)
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 34)
        }
    }
}

/// Bild-Kachel 220 × 220, Radius 40, mit Lichtfleck und Tiefenschatten.
private struct ProductImageTile: View {
    let k: SheetTheme
    let image: UIImage?

    var body: some View {
        let dark = k.isDark
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                SVGIcon(Icon.cameraOff, size: 64, color: dark ? k.a.light.color() : .hex("#8AA0A4"), lineWidth: 1.4)
            }
        }
        .frame(width: 220, height: 220)
        .background(alignment: .topLeading) {
            // left -40, top -60, 220×160, radial-gradient(closest-side, rgba(255,255,255,.55), transparent)
            CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                              stops: [stop(.rgba(255, 255, 255, 0.55), 0), stop(.rgba(255, 255, 255, 0), 1)])
                .frame(width: 220, height: 160)
                .offset(x: -40, y: -60)
        }
        .clipShape(RR(40))
        .background(CSSBox(shape: RR(40), paint: dark
                               ? .linear(150, [stop(k.a.base.color(0.24), 0), stop(k.a.base.color(0.06), 1)])
                               : .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)]),
                           shadows: dark
                               ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.14)), .drop(0, 24, 40, -18, .rgba(0, 0, 0, 0.8))]
                               : [.inner(0, 1, 0, 0, .white), .inner(0, -8, 18, 0, .rgba(12, 40, 44, 0.06)),
                                  .drop(0, 24, 40, -20, .rgba(12, 40, 44, 0.35))]))
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        ProductImageSheet(item: ItemModel(name: "Butter", units: 1, measure: "pack"), k: SheetTheme(.light),
                          maxHeight: 790, onClose: {})
    }
    .ignoresSafeArea()
}
