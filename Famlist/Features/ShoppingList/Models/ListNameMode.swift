/*
 ListNameMode.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zweck des Namens-Sheets für Listen: neue Liste anlegen oder bestehende umbenennen.

 📝 Last Change:
 - Initial creation („Meine Listen“ im Hybrid-Design).
 ------------------------------------------------------------------------
 */

import Foundation

/// What the list name sheet does on confirm.
enum ListNameMode: Equatable {
    case create
    case rename(ListModel)

    var title: String {
        switch self {
        case .create: return "Neue Liste"
        case .rename: return "Liste umbenennen"
        }
    }

    var confirmLabel: String {
        switch self {
        case .create: return "Liste erstellen"
        case .rename: return "Speichern"
        }
    }

    var initialName: String {
        switch self {
        case .create: return ""
        case .rename(let list): return list.title
        }
    }
}
