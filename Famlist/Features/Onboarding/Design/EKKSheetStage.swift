/*
 EKKSheetStage.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bühne für Sheets mit frei wählbarem Hintergrund-Screen. In der App (hybridHosted) nur das Sheet.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OnboardingScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Bühne für Sheets mit frei wählbarem Hintergrund-Screen:
/// Hintergrund + `backdrop-filter: blur(3px)` + Abdunkelung `k.scrim`, Sheet unten bündig.
/// (`SheetScreen` legt fest `ListScreen` darunter; „Kategorie bearbeiten“ braucht „Kategorien verwalten“.)
struct EKKSheetStage<Background: View, Sheet: View>: View {
    let k: SheetTheme
    @ViewBuilder let background: () -> Background
    @ViewBuilder let sheet: () -> Sheet
    @Environment(\.hybridHosted) private var hosted

    var body: some View {
        if hosted {
            // App: Weichzeichner + Abdunkelung liegen beim Host.
            sheet()
        } else {
            ZStack(alignment: .bottom) {
                (background as () -> Background)()   // eindeutig: nicht View.background(ignoresSafeAreaEdges:)
                    .blur(radius: 3, opaque: false)
                    .allowsHitTesting(false)
                k.scrim
                sheet()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}

#Preview("EKKSheetStage", traits: .fixedLayout(width: 390, height: 844)) {
    EKKSheetStage(k: SheetTheme(.light)) {
        EKKScreenBackground(t: EKKTokens(.light))
    } sheet: {
        SheetSurface(k: SheetTheme(.light), height: 320) {
            EKKSectionLabel(text: "Beispiel", k: SheetTheme(.light)).padding(20)
        }
    }
}

#Preview("EKKSheetStage – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    EKKSheetStage(k: SheetTheme(.dark)) {
        EKKScreenBackground(t: EKKTokens(.dark))
    } sheet: {
        SheetSurface(k: SheetTheme(.dark), height: 320) {
            EKKSectionLabel(text: "Beispiel", k: SheetTheme(.dark)).padding(20)
        }
    }
}
