/*
 OverlayIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - SVG-Icons der Overlays (Pfade exakt aus dem HTML, 24er-viewBox).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/OverlayScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Icons (Pfade exakt aus dem HTML, 24er-viewBox)

enum OverlayIcon {
    static let members: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5s5.5 1.5 6.5 4.5M19.5 9a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0zM16 14.6c2.6.2 4.6 1.6 5.5 4.4")]
    static let box: [SVGElement] = [.path("M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5zM3.5 7.5 12 12l8.5-4.5M12 12v9")]
    static let tag: [SVGElement] = [.path("M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8zM8 7.2v1.6")]
    static let settings: [SVGElement] = [.path("M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM12 2.5v3M12 18.5v3M4.6 4.6l2.1 2.1M17.3 17.3l2.1 2.1M2.5 12h3M18.5 12h3M4.6 19.4l2.1-2.1M17.3 6.7l2.1-2.1")]
    static let sortCategory: [SVGElement] = [.path("M4 6h10M4 12h7M4 18h4M17 5v14M14 16l3 3 3-3")]
    static let alphabetical: [SVGElement] = [.path("M4 18l4-12 4 12M5.3 14h5.4M14 6h6l-6 12h6")]
    static let clock: [SVGElement] = [.path("M12 7v5l3 2M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z")]
    static let grip: [SVGElement] = [.path("M9 5h.01M15 5h.01M9 12h.01M15 12h.01M9 19h.01M15 19h.01")]
    static let moveDown: [SVGElement] = [.path("M12 4v12M7 11l5 5 5-5M5 20h14")]
    static let clipboard: [SVGElement] = [.path("M9 3.5h6a1 1 0 0 1 1 1V6a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V4.5a1 1 0 0 1 1-1zM16 5h1.5A1.5 1.5 0 0 1 19 6.5v13a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-13A1.5 1.5 0 0 1 6.5 5H8")]
    static let checkAll: [SVGElement] = [.path("M18 6 7 17l-5-5M22 10l-7.5 7.5L13 16")]
}
