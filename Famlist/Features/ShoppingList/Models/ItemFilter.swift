/*
 ItemFilter.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeige-Filter der Listen-Tabs „Alle · Offen · Erledigt“.

 🔰 Notes for Beginners:
 - Reiner UI-Zustand: Der Filter blendet nur Abschnitte aus, er verändert keine Daten
   und wird deshalb weder in SwiftData gespeichert noch synchronisiert.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import Foundation

/// Welche Artikel die Liste anzeigt.
enum ItemFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case open = "Offen"
    case done = "Erledigt"

    var id: String { rawValue }

    /// Offene Artikel (nach Kategorie gruppiert) werden gezeigt.
    var showsOpenItems: Bool { self != .done }

    /// Der Abschnitt „Abgehakte Artikel“ wird gezeigt.
    var showsCheckedItems: Bool { self != .open }
}
