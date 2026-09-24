/*
 OverlaySwitch.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Statischer Schalter „an“ (51 × 31) wie im Sortier-Menü.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Schalter (nur Zustand „an“ im Design): 51 × 31, Radius 16, Verlauf toggleOn,
/// Knopf 25 weiß, oben/rechts 3, Schatten 0 2 4 rgba(0,0,0,.2).
struct OverlaySwitch: View {
    let k: OverlayTheme
    /// Das Design zeigt nur „an“. „Aus“ nutzt `toggleOff` aus ListAccountTokens (Settings.dc.html).
    var isOn = true

    private var offColor: Color { k.isDark ? .rgba(255, 255, 255, 0.14) : .hex("#DCE5E6") }

    var body: some View {
        ZStack(alignment: isOn ? .topTrailing : .topLeading) {
            if isOn {
                CSSBox(shape: Pill, paint: k.toggleOn)
            } else {
                Pill.fill(offColor)
            }
            CSSBox(shape: Circle(), paint: .color(.white), shadows: [.drop(0, 2, 4, 0, .rgba(0, 0, 0, 0.2))])
                .frame(width: 25, height: 25)
                .padding(3)
        }
        .frame(width: 51, height: 31)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOn)
        .accessibilityElement()
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "An" : "Aus")
    }
}
