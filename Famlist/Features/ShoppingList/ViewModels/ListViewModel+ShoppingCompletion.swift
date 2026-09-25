/*
 ListViewModel+ShoppingCompletion.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Erkennt „Einkauf erledigt“: Der Nutzer hakt den letzten offenen Artikel ab.

 🔰 Notes for Beginners:
 - Aufrufer (toggleItemChecked, Alle abhaken) merken sich vorher `isShoppingComplete` und melden danach
   `noteCheckChange(wasComplete:)`. Nur der Wechsel offen → erledigt setzt `shoppingCompletedEvent`.
 - Listenwechsel und Realtime-Updates laufen nicht hier durch und lösen deshalb nichts aus.
 - Rein lokal (Offline-First): liest nur `items`, kein Netzwerk.

 📝 Last Change:
 - Initial creation (Einkauf erledigt anbieten).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// true, wenn die Liste Artikel hat und alle abgehakt sind.
    var isShoppingComplete: Bool {
        !items.isEmpty && items.allSatisfy(\.isChecked)
    }

    /// Meldet den Übergang „noch offen → alles erledigt“ nach einer Nutzeraktion.
    func noteCheckChange(wasComplete: Bool) {
        guard !wasComplete, isShoppingComplete else { return }
        logVoid(params: (action: "shoppingCompleted", listId: listId.uuidString, count: items.count))
        UserLog.Data.shoppingCompleted(list: defaultList?.title ?? "Liste", count: items.count)
        shoppingCompletedEvent = UUID()
    }
}
