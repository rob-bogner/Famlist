/*
 ActiveListSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Welches Hybrid-Sheet gerade über der Liste liegt (nil = keines).

 🔰 Notes for Beginners:
 - Es ist immer höchstens ein Sheet offen. „Neu anlegen“ in der Suche ersetzt das Such-Sheet
   durch „Neuer Artikel“, statt ein zweites Sheet darüber zu stapeln.
 - Die Werte tragen nur Wert-Typen (ItemModel), keine SwiftData-Modelle.

 📝 Last Change:
 - Sheets „Meine Listen“ und Listen-Name ergänzt.
 ------------------------------------------------------------------------
 */

import Foundation

/// The Hybrid sheet currently presented above the shopping list.
enum ActiveListSheet: Equatable, Identifiable {
    case search
    case newItem(initialName: String, barcode: String? = nil)
    /// Barcode-Scanner (Vollbild, Kamera).
    case barcode
    /// Artikel verwalten (Artikelstamm).
    case manageItems
    /// Artikel des Artikelstamms bearbeiten (aus „Artikel verwalten“).
    case editCatalog(ItemCatalogEntry)
    case edit(ItemModel)
    case productImage(ItemModel)
    case lists
    case listName(ListNameMode)
    /// Neue Liste (mit „Als Favorit“).
    case createList
    /// Listen-Optionen (langer Druck in „Meine Listen“); liegt über „Meine Listen“.
    case listOptions(ListModel)
    /// Mitglieder & Teilen einer Liste.
    case shareMembers(ListModel)
    case settings
    case editProfile
    /// „Konto löschen?“; liegt über den Einstellungen.
    case deleteAccount

    var id: String {
        switch self {
        case .search: return "search"
        case .newItem: return "newItem"
        case .barcode: return "barcode"
        case .manageItems: return "manageItems"
        case .editCatalog(let entry): return "editCatalog-\(entry.id)"
        case .edit(let item): return "edit-\(item.id)"
        case .productImage(let item): return "image-\(item.id)"
        case .lists: return "lists"
        case .listName: return "listName"
        case .createList: return "createList"
        case .listOptions(let list): return "listOptions-\(list.id)"
        case .shareMembers(let list): return "shareMembers-\(list.id)"
        case .settings: return "settings"
        case .editProfile: return "editProfile"
        case .deleteAccount: return "deleteAccount"
        }
    }
}

extension ActiveListSheet {
    /// Sheet, das weichgezeichnet UNTER diesem liegt (Design: ListOptions/CreateList über MyLists, DeleteAccount über Settings).
    var baseSheet: ActiveListSheet? {
        switch self {
        case .listOptions, .createList, .listName: return .lists
        case .deleteAccount: return .settings
        default: return nil
        }
    }

    /// Unterliegende Sheets als Menü/Dialog (skaliert ein) statt als Sheet von unten.
    var isPopup: Bool {
        switch self {
        case .listOptions, .deleteAccount: return true
        default: return false
        }
    }
}
