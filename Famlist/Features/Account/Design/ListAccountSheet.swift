/*
 ListAccountSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet der Gruppe „Listen & Konto“: Griff → 12 → Titelzeile, Innenabstand 10 / 20 / 34.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Sheet mit `display: flex; flex-direction: column; padding: 10px 20px 34px 20px`:
/// Griff → 12 → Titelzeile, danach der Inhalt (oben ausgerichtet).
struct ListAccountSheet<Content: View>: View {
    let k: SheetTheme
    let height: CGFloat
    let title: String
    var onClose: () -> Void = {}
    @ViewBuilder let content: () -> Content

    var body: some View {
        SheetSurface(k: k, height: height) {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: title, k: k, onClose: onClose)
                content()
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityAction(.escape, onClose)          // VoiceOver „Zurück“ wie HybridSheetLayer
    }
}

#Preview("ListAccountSheet", traits: .fixedLayout(width: 390, height: 844)) {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        ListAccountSheet(k: SheetTheme(.light), height: 360, title: "Liste erstellen") {
            ListAccountSectionLabel(text: "Name", t: ListAccountTokens(.light))
        }
    }
    .ignoresSafeArea()
}

#Preview("ListAccountSheet – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        ListAccountSheet(k: SheetTheme(.dark), height: 360, title: "Liste erstellen") {
            ListAccountSectionLabel(text: "Name", t: ListAccountTokens(.dark))
        }
    }
    .ignoresSafeArea()
}
