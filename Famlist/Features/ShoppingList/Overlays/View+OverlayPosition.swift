/*
 View+OverlayPosition.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Positionen der Dock-Menüs (links 20, unten 108) und Toasts (links/rechts 20, unten n).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OverlayScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Dock-Menü-Position: `left: 20px; bottom: 108px; width: 270px`.
extension View {
    func overlayDockMenuPosition() -> some View {
        self
            .padding(.leading, 20)
            .padding(.bottom, 108)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// Toast: `left: 20px; right: 20px; bottom: <bottom>`.
    func overlayToastPosition(bottom: CGFloat) -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.bottom, bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
