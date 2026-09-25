/*
 ListViewModel+ItemStatus.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Status-Aktionen der Hybrid-Liste: „Nicht verfügbar“ umschalten und
   „Alle abhaken“ für eine einzelne Kategorie.

 🔰 Notes for Beginners:
 - Beide Aktionen laufen über updateItem() → SyncEngine. Jede Änderung bekommt dadurch
   einen neuen HLC-Zeitstempel und wird per Last-Writer-Wins synchronisiert.
 - Die UI wird optimistisch sofort aktualisiert (wie bei toggleItemChecked).

 📝 Last Change:
 - Kategorie abhaken: gebündelt über die SyncEngine, meldet „Einkauf erledigt“; kein Stamm-Update (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {

    // MARK: - Availability

    /// Marks an item as "not available in the store" or makes it available again.
    func toggleItemUnavailable(_ item: ItemModel) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        updated.isUnavailable.toggle()
        items[index] = updated

        logVoid(params: (action: "toggleItemUnavailable", itemId: updated.id, isUnavailable: updated.isUnavailable))
        UserLog.Data.itemAvailabilityChanged(name: displayName(of: updated), isUnavailable: updated.isUnavailable)

        updateItem(updated, trackPendingAnimation: true, updateCatalog: false)
    }

    // MARK: - Check All in Category

    /// Checks every open item of the given category ("Alle abhaken" in the section header).
    func checkAllItems(in categoryName: String) {
        let targets = uncheckedItems.filter { CategoryResolver.name(for: $0.category, in: categoryOrder) == categoryName }
        guard !targets.isEmpty else { return }

        logVoid(params: (action: "checkAllItems.inCategory", category: categoryName, count: targets.count))
        UserLog.Data.categoryItemsChecked(category: categoryName, count: targets.count)

        let wasComplete = isShoppingComplete
        let targetIDs = Set(targets.map(\.id))
        for index in items.indices where targetIDs.contains(items[index].id) {
            items[index].isChecked = true
        }
        items = ListViewModel.currentSortOrder.apply(to: items)
        noteCheckChange(wasComplete: wasComplete)       // „Einkauf erledigt“ auch über den Kategorie-Kopf

        let changed = items.filter { targetIDs.contains($0.id) }
        guard let syncEngine else { return }
        Task { await syncEngine.applyLocalChanges(changed) }
    }

    // MARK: - Helpers

    /// "Marke Name" for user logs; falls back to "Artikel".
    private func displayName(of item: ItemModel) -> String {
        let name = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Artikel" : name
    }
}
