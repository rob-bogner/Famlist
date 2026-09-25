/*
 GlassToast.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Toast aus dunklem Glas (Light und Dark), feste Höhe, Rahmen 1.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Toast

/// Dunkles Glas-Toast: feste Höhe, Radius, border-box mit Rahmen 1, Inhalt 12 auseinander.
/// `leading`/`trailing` = CSS-padding (ohne Rahmen).
struct GlassToast<Content: View>: View {
    let k: OverlayTheme
    let height: CGFloat
    let radius: CGFloat
    let leading: CGFloat
    let trailing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.leading, leading + 1)
        .padding(.trailing, trailing + 1)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(CSSBox(shape: RR(radius), paint: .color(k.toast), border: 1, borderColor: k.toastBorder,
                           shadows: k.toastShadow))
    }
}
