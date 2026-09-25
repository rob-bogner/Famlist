/*
 ListViewModel+ReceiptPrices.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Kassenzettel prüfen“ → „Preise übernehmen“: setzt die Bon-Preise als neue Artikelpreise.

 🔰 Notes for Beginners:
 - Geändert werden alle gleichnamigen Artikel der geöffneten Liste und der Eintrag im Artikelstamm
   (Name ohne Groß/klein und Rand-Leerzeichen, wie bei applyCatalogEdit).
 - Offline zuerst: Listenartikel über `updateItem` (SwiftData + SyncEngine), der Artikelstamm über
   die Warteschlange des OfflineItemCatalogRepository. Ohne Netz wird beides später gesendet.
 - Nur der Preis ändert sich; Menge, Abhak-Status und alle anderen Felder bleiben.
 - Andere Listen sind nicht geladen und behalten ihren Preis.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// Returns the number of articles whose price changed (list and catalog counted once per name).
    @discardableResult
    func applyReceiptPrices(_ changes: [ReceiptPriceChange]) async -> Int {
        guard !changes.isEmpty else { return 0 }
        let prices = Dictionary(changes.map { ($0.key, $0.price) }, uniquingKeysWith: { _, last in last })
        var changedKeys = Set<String>()

        for item in Self.receiptPriceUpdates(for: items, prices: prices) {
            updateItem(item, suppressUserLog: true, updateCatalog: false)
            changedKeys.insert(CatalogOperation.key(item.name))
        }
        changedKeys.formUnion(await applyReceiptPricesToCatalog(prices))

        logVoid(params: (action: "applyReceiptPrices", requested: changes.count, changed: changedKeys.count))
        if !changedKeys.isEmpty { UserLog.Data.itemPricesUpdated(count: changedKeys.count) }
        return changedKeys.count
    }

    /// Listenartikel mit neuem Preis (nur die, deren Preis sich wirklich ändert).
    static func receiptPriceUpdates(for items: [ItemModel], prices: [String: Double]) -> [ItemModel] {
        items.compactMap { item in
            guard let price = prices[CatalogOperation.key(item.name)], abs(item.price - price) > 0.004 else { return nil }
            var updated = item
            updated.price = price
            return updated
        }
    }

    /// Artikelstamm: Einträge mit neuem Preis aktualisieren. Liefert die Schlüssel der geänderten Einträge.
    private func applyReceiptPricesToCatalog(_ prices: [String: Double]) async -> Set<String> {
        guard let catalogRepository, let entries = try? await catalogRepository.fetchAll() else { return [] }
        var changed = Set<String>()
        for entry in entries {
            let key = CatalogOperation.key(entry.name)
            guard let price = prices[key], abs(entry.price - price) > 0.004 else { continue }
            var updated = entry
            updated.price = price
            do {
                try await catalogRepository.update(updated)
                changed.insert(key)
            } catch {
                logVoid(params: (action: "applyReceiptPrices.catalog.failed", name: entry.name,
                                 error: (error as NSError).localizedDescription))
            }
        }
        return changed
    }
}
