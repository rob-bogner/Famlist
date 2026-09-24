/*
 ListOverlay.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Welches Overlay gerade über der Liste liegt: Kontext-Menü ☰ oder eines der drei Dock-Menüs.

 🔰 Notes for Beginners:
 - Dock-Menüs (sort, copy, delete) liegen über einer leichten Abdunkelung; das Dock selbst bleibt
   darüber sichtbar und zeigt den gewählten Knopf als Pille.
 - Das Kontext-Menü dunkelt die ganze Liste inklusive Dock ab.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import Foundation

/// Overlay presented above the shopping list.
enum ListOverlay: Equatable {
    case menu
    case sort
    case copy
    case delete

    /// true = Dock liegt über der Abdunkelung (Dock-Menüs).
    var keepsDockOnTop: Bool { self != .menu }

    /// Dock-Auswahl, solange das Menü offen ist.
    var dockActive: DockActive {
        switch self {
        case .menu: return .none
        case .sort: return .sort
        case .copy: return .copy
        case .delete: return .delete
        }
    }
}
