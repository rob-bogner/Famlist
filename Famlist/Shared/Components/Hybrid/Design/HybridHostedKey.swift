/*
 HybridHostedKey.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Umgebungswert `hybridHosted`: Läuft ein Design-Screen in der App (true) oder als Vorschau (false)?

 🔰 Notes for Beginners:
 - Jeder Screen aus design-handoff/MyListUI legt sich selbst einen Hintergrund unter: die
   Beispiel-Liste, weichgezeichnet und abgedunkelt. In der App liegt dort die ECHTE Liste.
 - Setzt der Host (ShoppingListView, RootView) `hybridHosted = true`, zeichnen die Hintergrund-
   Bausteine (ListAccountBackdrop, EKKSheetStage, OverlayStage, SheetScreen) nur noch ihren Inhalt.
   Weichzeichner und Abdunkelung kommen dann vom Host.
 - Außerdem begrenzt `hybridSheetMaxHeight` die festen Sheet-Höhen (790 …) auf kleinen Geräten.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

private struct HybridHostedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct HybridSheetMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = .infinity
}

extension EnvironmentValues {
    /// true = Design-Screen läuft in der App; der eingebaute Beispiel-Hintergrund entfällt.
    var hybridHosted: Bool {
        get { self[HybridHostedKey.self] }
        set { self[HybridHostedKey.self] = newValue }
    }

    /// Größte erlaubte Sheet-Höhe (Bildschirmhöhe − 54). Vorschauen: unbegrenzt.
    var hybridSheetMaxHeight: CGFloat {
        get { self[HybridSheetMaxHeightKey.self] }
        set { self[HybridSheetMaxHeightKey.self] = newValue }
    }
}
