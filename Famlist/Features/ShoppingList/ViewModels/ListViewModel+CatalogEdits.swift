/*
 ListViewModel+CatalogEdits.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Übernimmt Änderungen aus „Artikel verwalten“ in die Artikel der geöffneten Liste.

 🔰 Notes for Beginners:
 - Listenartikel sind Kopien des Artikelstamms (eigene ID). Zugeordnet wird – wie beim Speichern
   in den Artikelstamm (Upsert nach Name) – über den Namen, ohne Groß/klein und Leerzeichen am Rand.
 - Übernommen werden nur Felder, die sich im Artikelstamm wirklich geändert haben. Menge, Abhak-Status
   und alles, was nur in der Liste geändert wurde, bleiben erhalten.
 - Gespeichert wird offline zuerst über `updateItem` (SwiftData + SyncEngine); der Artikelstamm
   wird dabei nicht noch einmal geschrieben.
 - Nur die geöffnete Liste: Andere Listen sind nicht geladen.

 📝 Last Change:
 - Initial creation (Änderungen im Artikelstamm erschienen nicht in der Liste).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// Returns the number of list items that were changed.
    @discardableResult
    func applyCatalogEdit(from old: ItemCatalogEntry, to new: ItemCatalogEntry) -> Int {
        let key = CatalogOperation.key(old.name)
        var changed = 0
        for item in items where CatalogOperation.key(item.name) == key {
            let updated = Self.applyingCatalogChanges(to: item, from: old, to: new)
            guard !Self.sameProductFields(updated, item) else { continue }
            updateItem(updated, suppressUserLog: true, updateCatalog: false)
            changed += 1
        }
        if changed > 0 {
            logVoid(params: (action: "applyCatalogEdit", name: new.name, changedItems: changed))
        }
        return changed
    }

    /// Setzt nur die Felder, in denen sich `old` und `new` unterscheiden.
    static func applyingCatalogChanges(to item: ItemModel, from old: ItemCatalogEntry, to new: ItemCatalogEntry) -> ItemModel {
        var u = item
        if old.name != new.name { u.name = new.name }
        if old.brand != new.brand { u.brand = new.brand }
        if old.category != new.category { u.category = new.category }
        if old.productDescription != new.productDescription { u.productDescription = new.productDescription }
        if old.measure != new.measure { u.measure = new.measure }
        if old.price != new.price { u.price = new.price }
        if old.imageData != new.imageData { u.imageData = new.imageData }
        return u
    }

    /// Vergleicht nur die Felder, die der Artikelstamm liefert.
    static func sameProductFields(_ a: ItemModel, _ b: ItemModel) -> Bool {
        a.name == b.name && a.brand == b.brand && a.category == b.category
            && a.productDescription == b.productDescription && a.measure == b.measure
            && a.price == b.price && a.imageData == b.imageData
    }
}
