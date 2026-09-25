/*
 ListViewModel+Categories.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel neu zuordnen, wenn eine Kategorie umbenannt oder gelöscht wird.

 🔰 Notes for Beginners:
 - Artikel speichern den Kategorie-Namen als Text. Nach „Umbenennen“ bekommen alle Artikel mit dem alten
   Namen den neuen; nach „Löschen“ stehen sie unter „Sonstiges“ (SPEC §3.11).
 - Betroffen sind die Artikel aller Listen, die lokal gespeichert sind. Die Änderung läuft über die
   SyncEngine (Offline-First, HLC) und erreicht so auch die anderen Mitglieder geteilter Listen.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// Setzt bei allen lokal bekannten Artikeln mit Kategorie `oldName` die Kategorie `newName`.
    /// - Returns: Anzahl geänderter Artikel.
    @discardableResult
    func reassignCategory(from oldName: String, to newName: String) -> Int {
        guard oldName != newName else { return 0 }
        let listIds = Set(allLists.map(\.id) + [listId])
        var changed = 0
        for id in listIds {
            let entities = (try? itemStore.fetchItems(listId: id)) ?? []
            for entity in entities where (entity.category ?? "").caseInsensitiveCompare(oldName) == .orderedSame {
                var item = entity.toItemModel()
                item.category = newName
                changed += 1
                if id == listId {
                    updateItem(item, suppressUserLog: true)
                } else if let syncEngine {
                    Task { await syncEngine.updateItem(item) }
                }
            }
        }
        logVoid(params: (action: "reassignCategory", from: oldName, to: newName, count: changed))
        return changed
    }
}
