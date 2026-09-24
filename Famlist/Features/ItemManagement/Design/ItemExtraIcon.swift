/*
 ItemExtraIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icons nur für Barcode-Scanner und Preisverlauf (Pfade exakt aus dem HTML).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ItemExtraScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Icons, die nur hier vorkommen (Pfade exakt aus dem HTML).
enum ItemExtraIcon {
    /// Blitz (Licht) – BarcodeScan
    static let bolt: [SVGElement] = [.path("M13 2 4 14h7l-1 8 9-12h-7z")]
    /// Wagen mit Rädern als Bogen-Pfade – BarcodeScan
    static let cartArcs: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7"),
                                         .path("M10.7 19a1.2 1.2 0 1 1-2.4 0 1.2 1.2 0 0 1 2.4 0zM17.7 19a1.2 1.2 0 1 1-2.4 0 1.2 1.2 0 0 1 2.4 0z")]
    /// Wagen ohne Räder – PriceHistory
    static let cartBody: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7")]
}
