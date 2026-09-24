/*
 PopoverPointer.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeiger-Raute eines Popovers (15 × 15, 45° gedreht, Rahmen rechts/unten).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Zeiger-Raute: `width/height: 14px; border-right/bottom: 1px; transform: rotate(45deg)`.
/// Kein box-sizing → Rahmenbox 15 × 15, gedreht um ihre Mitte. Hintergrund liegt unter dem Rahmen.
struct PopoverPointer: View {
    let fill: Color
    let border: Color

    var body: some View {
        ZStack {
            Rectangle().fill(fill)
            PointerBorderShape().fill(border)
        }
        .frame(width: 15, height: 15)
        .rotationEffect(.degrees(45))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Rahmen rechts + unten als eine Fläche (Ecke nicht doppelt deckend, wie in CSS).
private struct PointerBorderShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: r.maxX - 1, y: r.minY, width: 1, height: r.height))
        p.addRect(CGRect(x: r.minX, y: r.maxY - 1, width: r.width - 1, height: 1))
        return p
    }
}
