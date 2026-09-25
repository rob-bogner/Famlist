/*
 ListAccountToggle.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schalter wie im Design: 51 × 31, Knopf 25, Verlauf „an“, grau „aus“.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// iOS-Schalter wie im Design: 51 × 31, Radius 16, Knopf 25 (3 pt Rand), Schatten 0 2 4 rgba(0,0,0,.2).
struct ListAccountToggle: View {
    let t: ListAccountTokens
    @Binding var isOn: Bool
    var label: String = ""

    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                if isOn {
                    CSSBox(shape: Pill, paint: t.toggleOn)
                } else {
                    Pill.fill(t.toggleOff)
                }
                Color.clear
                    .frame(width: 25, height: 25)
                    .background(CSSBox(shape: Circle(), paint: .color(.white),
                                       shadows: [.drop(0, 2, 4, 0, .rgba(0, 0, 0, 0.2))]))
                    .padding(3)
            }
            .frame(width: 51, height: 31)
            .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Ein" : "Aus")
        .accessibilityAddTraits(.isToggle)
    }
}
