/*
 OverlayStage.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bühne eines Overlay-Artboards: Liste → Abdunkelung → Dock → Overlay. In der App (hybridHosted) nur das Overlay.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Bühne

/// Aufbau aller Overlay-Artboards (absolute Ebenen, 390 × 844):
/// ListScreen → (Scrim mit Blur) → (DockView erneut oben drauf, links 20 / unten 34) → Overlay.
/// Das Overlay positioniert sich selbst (z. B. per `.frame(maxWidth:maxHeight:alignment:)`).
struct OverlayStage<Overlay: View>: View {
    let appearance: Appearance
    var accentHex: String? = nil
    var listState: ListRowState = .normal
    var showsScrim = true
    /// `nil` → kein zusätzliches Dock über der Liste
    var dock: DockActive? = nil
    var dockPill: DockPill = .open
    var onDismiss: () -> Void = {}
    @ViewBuilder let overlay: () -> Overlay
    @Environment(\.hybridHosted) private var hosted

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        ZStack {
            if hosted {
                // App: Liste, Abdunkelung und Dock zeichnet der Host (ShoppingListView).
                overlay()
            } else {
                if showsScrim {
                    OverlayScrim(color: k.scrim, onTap: onDismiss) {
                        DesignListScreen(appearance: appearance, accentHex: accentHex, state: listState)
                    }
                } else {
                    DesignListScreen(appearance: appearance, accentHex: accentHex, state: listState)
                }

                if let dock {
                    OverlayDockLayer(appearance: appearance, accentHex: accentHex, active: dock, pill: dockPill)
                }

                overlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()                                   // overflow: hidden
        .ignoresSafeArea()
    }
}
