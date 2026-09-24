/*
 EKKSectionLabel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abschnitts-Überschrift 13/600 in Großbuchstaben.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Abschnitts-Überschrift: 13/600, letter-spacing .04em, Großbuchstaben, sub, Einzug 4.
struct EKKSectionLabel: View {
    let text: String
    let k: SheetTheme

    var body: some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .tracking(0.52)
            .textCase(.uppercase)
            .foregroundStyle(k.sub)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
