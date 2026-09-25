/*
 EKKTextButton.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Text-Button ohne Fläche, 48 hoch, 15/600.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Text-Button ohne Fläche: Höhe 48, 15/600.
struct EKKTextButton: View {
    let title: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.dm(15, 600))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("EKKTextButton") {
    EKKTextButton(title: "Später", color: SheetTheme(.light).accent)
        .padding(20)
}

#Preview("EKKTextButton – Dark") {
    EKKTextButton(title: "Später", color: SheetTheme(.dark).accent)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
