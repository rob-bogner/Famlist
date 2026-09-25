/*
 DockPill.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand der Liste für das Dock: offen, alles erledigt, leer.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/Dock.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Zustand der Liste, steuert den ersten Knopf und das Dimmen.
enum DockPill {
    case open      // „Alle abhaken“
    case allDone   // „Zurücksetzen“
    case empty     // Abhaken / Kopieren / Löschen gedimmt, Sortieren bleibt aktiv
}
