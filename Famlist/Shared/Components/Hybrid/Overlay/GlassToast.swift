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

/// Dunkles Glas-Toast: Designhöhe (wächst nur bei großer iOS-Schrift), Radius, border-box mit Rahmen 1, Inhalt 12 auseinander.
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
        .padding(.vertical, 6)                 // nur wirksam, wenn große iOS-Schrift den Text umbricht
        .frame(maxWidth: .infinity)
        .frame(minHeight: height)              // Designhöhe; wächst statt abzuschneiden
        .background(CSSBox(shape: RR(radius), paint: .color(k.toast), border: 1, borderColor: k.toastBorder,
                           shadows: k.toastShadow))
    }
}

#Preview("GlassToast") {
    let k = OverlayTheme(.light)
    GlassToast(k: k, height: 56, radius: 20, leading: 16, trailing: 16) {
        SVGIcon(Icon.check, size: 20, color: k.toastIcon, lineWidth: 1.9)
        Text("Liste kopiert").font(AppFont.dm(15, 500)).foregroundStyle(k.toastText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
}

#Preview("GlassToast – Dark") {
    let k = OverlayTheme(.dark)
    GlassToast(k: k, height: 56, radius: 20, leading: 16, trailing: 16) {
        SVGIcon(Icon.check, size: 20, color: k.toastIcon, lineWidth: 1.9)
        Text("Liste kopiert").font(AppFont.dm(15, 500)).foregroundStyle(k.toastText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
