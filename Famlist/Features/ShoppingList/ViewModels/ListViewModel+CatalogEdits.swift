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
 - Fotos aus dem Artikelstamm in Listenartikel ohne Foto übernehmen; fehlende Angaben beim Hinzufügen ergänzen.
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

    // MARK: - Fehlende Angaben ergänzen

    /// Übernimmt Foto, Preis, Marke, Kategorie, Beschreibung und Einheit aus `source`,
    /// aber nur dort, wo `item` noch nichts hat. Menge, Abhak-Status und Name bleiben.
    static func fillingMissingFields(of item: ItemModel, from source: ItemModel) -> ItemModel {
        var u = item
        if isBlank(u.imageData), !isBlank(source.imageData) { u.imageData = source.imageData }
        if u.price <= 0, source.price > 0 { u.price = source.price }
        if isBlank(u.brand), !isBlank(source.brand) { u.brand = source.brand }
        if isBlank(u.category), !isBlank(source.category) { u.category = source.category }
        if isBlank(u.productDescription), !isBlank(source.productDescription) { u.productDescription = source.productDescription }
        if u.measure.isEmpty, !source.measure.isEmpty { u.measure = source.measure }
        return u
    }

    private static func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    /// Listenartikel ohne Foto bekommen das Foto aus dem Artikelstamm (gleicher Name).
    /// Läuft beim Öffnen einer Liste; offline aus dem lokalen Stamm-Zwischenspeicher.
    func backfillImagesFromCatalog() async {
        guard let catalogRepository, items.contains(where: { Self.isBlank($0.imageData) }) else { return }
        guard let entries = try? await catalogRepository.fetchAll() else { return }
        let images = Dictionary(entries.compactMap { entry -> (String, String)? in
            guard let data = entry.imageData, !Self.isBlank(data) else { return nil }
            return (CatalogOperation.key(entry.name), data)
        }, uniquingKeysWith: { first, _ in first })
        var filled = 0
        for item in items where Self.isBlank(item.imageData) {
            guard let data = images[CatalogOperation.key(item.name)] else { continue }
            var updated = item
            updated.imageData = data
            updateItem(updated, suppressUserLog: true, updateCatalog: false)
            filled += 1
        }
        if filled > 0 {
            logVoid(params: (action: "backfillImagesFromCatalog", listId: listId, filled: filled))
        }
    }
}
