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
    case newItem(initialName: String)
    case edit(ItemModel)
    case productImage(ItemModel)
    case lists
    case listName(ListNameMode)

    var id: String {
        switch self {
        case .search: return "search"
        case .newItem: return "newItem"
        case .edit(let item): return "edit-\(item.id)"
        case .productImage(let item): return "image-\(item.id)"
        case .lists: return "lists"
        case .listName: return "listName"
        }
    }
}
