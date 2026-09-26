/*
 SheetSurface.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet-Fläche: obere Radien 34, Hintergrund, Schatten, 1-px-Oberkante (Dark), feste Höhe.

 🔰 Notes for Beginners:
 - Baustein der Hybrid-Sheets. Maße und Farben 1:1 aus dem Design (siehe Core/DesignSystem/Hybrid/README.md).

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Sheet-Fläche: obere Radien 34, Hintergrund, Schatten, 1-px-Oberkante (Dark), feste Höhe, unten bündig.
struct SheetSurface<Content: View>: View {
    let k: SheetTheme
    let height: CGFloat
    @ViewBuilder let content: () -> Content
    /// Auf Geräten, die niedriger als 844 pt sind, darf das Sheet nicht über den Bildschirm hinausragen.
    @Environment(\.hybridSheetMaxHeight) private var maxHeight

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .circular)
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.top, 1)                      // border-top: 1px (Light: transparent, belegt aber Platz)
            .frame(height: min(height, maxHeight), alignment: .top)
            .overlay(alignment: .top) {
                if k.isDark {
                    ZStack(alignment: .top) {
                        // border-top: 1px rgba(255,255,255,.08)
                        TopBorderHairline(radius: 34, color: k.sheetTopBorder)
                        // box-shadow: inset 0 1px 0 rgba(255,255,255,.06) – liegt innerhalb des Rahmens (y 1…2)
                        TopBorderHairline(radius: 34, color: .rgba(255, 255, 255, 0.06))
                            .padding(.top, 1)
                    }
                }
            }
            .clipShape(shape)                    // overflow: hidden
            .background(CSSBox(shape: shape, paint: k.sheet, shadows: k.sheetShadow))
    }
}

#Preview("SheetSurface", traits: .fixedLayout(width: 390, height: 844)) {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        SheetSurface(k: SheetTheme(.light), height: 420) {
            SheetHeader(title: "Beispiel", k: SheetTheme(.light), onClose: {}).padding(20)
        }
    }
    .ignoresSafeArea()
}

#Preview("SheetSurface – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        SheetSurface(k: SheetTheme(.dark), height: 420) {
            SheetHeader(title: "Beispiel", k: SheetTheme(.dark), onClose: {}).padding(20)
        }
    }
    .ignoresSafeArea()
}
