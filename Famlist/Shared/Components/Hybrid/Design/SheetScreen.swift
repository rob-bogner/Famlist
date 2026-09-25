/*
 SheetScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bühne eines Sheet-Artboards: Design-Liste weichgezeichnet + Abdunkelung + Sheet unten. In der App (hybridHosted) nur das Sheet.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/SheetComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Liste im Hintergrund (Zustand .normal) + `backdrop-filter: blur(3px)` + Abdunkelung.
struct SheetScreen<Sheet: View>: View {
    let appearance: Appearance
    let accentHex: String?
    @ViewBuilder let sheet: () -> Sheet
    @Environment(\.hybridHosted) private var hosted

    var body: some View {
        if hosted {
            // App: Das Sheet bestimmt seine Höhe selbst; der Host legt es unten bündig ab.
            sheet()
        } else {
            let k = SheetTheme(appearance, accentHex: accentHex)
            ZStack(alignment: .bottom) {
                DesignListScreen(appearance: appearance, accentHex: accentHex, state: .normal)
                    .blur(radius: 3, opaque: false)      // opaque: true wird pixelig (siehe ShoppingListView)
                    .allowsHitTesting(false)
                k.scrim
                sheet()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}
