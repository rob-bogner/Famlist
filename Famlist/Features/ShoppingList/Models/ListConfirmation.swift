/*
 ListConfirmation.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rückfragen vor folgenreichen Listen-Aktionen (Duplizieren und die drei Lösch-Varianten).

 🔰 Notes for Beginners:
 - Ein einziger confirmationDialog in ShoppingListView zeigt den jeweils anstehenden Fall.
 - Die Lösch-Texte entsprechen dem bisherigen Dialog aus FloatingBottomMenuBar.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import Foundation

/// A destructive or list-creating action that needs confirmation.
enum ListConfirmation: Identifiable {
    case duplicate
    case deleteChecked
    case deleteOpen
    case deleteAll

    var id: Self { self }

    var title: String {
        switch self {
        case .duplicate: return "Liste duplizieren?"
        case .deleteChecked: return "Erledigte löschen?"
        case .deleteOpen: return "Offene löschen?"
        case .deleteAll: return "Alle Artikel löschen?"
        }
    }

    var message: String {
        switch self {
        case .duplicate:
            return "Es entsteht eine neue Liste mit allen Artikeln. Alle Kopien starten als offen."
        case .deleteChecked, .deleteOpen, .deleteAll:
            return "Diese Aktion kann nicht rückgängig gemacht werden."
        }
    }

    var confirmLabel: String {
        switch self {
        case .duplicate: return "Duplizieren"
        case .deleteChecked: return "Erledigte löschen"
        case .deleteOpen: return "Offene löschen"
        case .deleteAll: return "Alle Artikel löschen"
        }
    }

    var isDestructive: Bool { self != .duplicate }
}
