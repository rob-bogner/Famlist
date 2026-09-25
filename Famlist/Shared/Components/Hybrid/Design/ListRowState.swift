/*
 ListRowState.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustände der Design-Liste (normal, abgehakt, Wisch-Aktionen, leer) für Vorschauen und Overlays.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListScreen.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum ListRowState {
    case normal
    case checked
    case swipe
    case empty
}
