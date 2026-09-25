/*
 ListAccountIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icons der Gruppe „Listen & Konto“ (Pfade exakt aus dem HTML).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Icons (Pfade exakt aus dem HTML, soweit nicht im Katalog `Icon`)

enum ListAccountIcon {
    /// ListOptions/ShareMembers „Duplizieren“ / „Link kopieren“ (Pfad-Variante, nicht `Icon.duplicate`)
    static let copy: [SVGElement] = [.path("M10 8h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2zM16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2")]
    /// „Mitglieder & Teilen“
    static let members: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5s5.5 1.5 6.5 4.5M19.5 9a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0zM16 14.6c2.6.2 4.6 1.6 5.5 4.4")]
    /// Person mit Plus (ShareMembers, leerer Zustand)
    static let personAdd: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5 1.6 0 3 .4 4.2 1.2M18 14v6M15 17h6")]
    /// Teilen (Pfeil aus Box)
    static let share: [SVGElement] = [.path("M12 3v12M8 7l4-4 4 4M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7")]
    /// Kamera (EditProfile, Kreis als Pfad)
    static let camera: [SVGElement] = [.path("M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z"),
                                       .path("M15.5 12.5a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0z")]
    /// Schloss (E-Mail nicht änderbar)
    static let lock: [SVGElement] = [.path("M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3")]
    /// Warnung (Konto löschen)
    static let warning: [SVGElement] = [.path("M12 4 2.5 20h19L12 4zM12 10v4.5M12 17.3v.2")]
}
