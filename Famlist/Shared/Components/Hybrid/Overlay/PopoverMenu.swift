/*
 PopoverMenu.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Popover-Fläche (Radius 24, Rahmen 1, padding 6) mit optionalem Zeiger nach unten.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Popover-Menü

/// Menü-Fläche: feste Breite (border-box), Rahmen 1, padding 6, Radius 24, Schatten.
/// `pointerLeft` = CSS `left` des Zeigers relativ zur Padding-Box (innerhalb des Rahmens), `bottom: -7px`.
struct PopoverMenu<Content: View>: View {
    let k: OverlayTheme
    let width: CGFloat
    var pointerLeft: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(7)                                  // 1 Rahmen + 6 padding
        .frame(width: width)
        .background(CSSBox(shape: RR(24), paint: .color(k.menu), border: 1, borderColor: k.menuBorder,
                           shadows: k.menuShadow))
        .overlay(alignment: .bottomLeading) {
            if let pointerLeft {
                // Zeiger-Box 15 × 15 (content-box 14 + Rahmen 1): links = 1 Rahmen + left,
                // Unterkante = Padding-Box-Unterkante + 7 = Menü-Unterkante − 1 + 7.
                PopoverPointer(fill: k.menuSolid, border: k.menuBorder)
                    .offset(x: 1 + pointerLeft, y: 6)
            }
        }
    }
}
