/*
 ListAccountBackdrop.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hintergrund-Artboard weichgezeichnet + Abdunkelung, darüber der Inhalt. In der App (hybridHosted) nur der Inhalt.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hintergrund-Artboard (per `dc-import`) + `backdrop-filter: blur(3px)` + Abdunkelung, darüber der Inhalt.
/// Ersetzt `SheetScreen`, weil der Hintergrund hier je nach Artboard wechselt (Hybrid, MyLists, Settings)
/// und die Abdunkelung je Artboard verschieden ist.
struct ListAccountBackdrop<Background: View, Content: View>: View {
    let scrim: Color
    var alignment: Alignment = .bottom
    @ViewBuilder let background: () -> Background
    @ViewBuilder let content: () -> Content
    @Environment(\.hybridHosted) private var hosted

    var body: some View {
        if hosted {
            // App: Weichzeichner + Abdunkelung liegen beim Host; unten bündige Sheets bestimmen ihre Höhe selbst,
            // alles andere (Menü, Dialog) füllt den Bildschirm und richtet sich selbst aus.
            if alignment == .bottom {
                content()
            } else {
                content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            }
        } else {
            designStage
        }
    }

    private var designStage: some View {
        ZStack(alignment: alignment) {
            (background as () -> Background)()   // eindeutig: nicht View.background(ignoresSafeAreaEdges:)
                .blur(radius: 3, opaque: false)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            scrim
                .allowsHitTesting(false)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
