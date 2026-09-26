/*
 WatchListViewModel.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand aller Uhr-Screens aus dem lokalen Speicher (Offline-First): Listen mit Status, aktive Liste,
   Abschnitte, Fortschritt, „Oft gekauft“. Baut sich bei jeder Änderung des Sync-Koordinators neu auf.
 - Aktionen (abhaken, Menge, hinzufügen, alle abhaken, zurücksetzen, Liste wählen) →
   WatchListViewModel+Actions.swift.

 🔰 Notes for Beginners:
 - Aktive Liste je Gerät (Watch-Plan §2): gemerkt in UserDefaults; beim ersten Start der Favorit, sonst die
   Standardliste, sonst die älteste.
 - Die Screens bekommen nur Anzeigewerte, nie SwiftData-Objekte.

 📝 Last Change:
 - Widget-Stand bei jeder Änderung (Watch-Plan Phase 6).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation

@MainActor
final class WatchListViewModel: ObservableObject {
    @Published private(set) var lists: [WatchListSummary] = []
    @Published private(set) var activeListId: UUID?
    @Published private(set) var title = "Famlist"
    @Published private(set) var sections: [WatchSectionDisplay] = []
    @Published private(set) var checkedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var frequent: [WatchFrequentItem] = []
    @Published private(set) var pendingChanges = 0
    /// Zählt jedes Abhaken hoch (Auslöser der Haptik).
    @Published var checkFeedback = 0

    let sync: WatchSyncCoordinator
    let defaults: UserDefaults
    /// Smart Stack und Komplikationen (App Group); nil in Tests ohne Widgets.
    private let widgets: WatchWidgetPublisher?
    /// Modelle der aktiven Liste (Grundlage für Aktionen).
    private(set) var items: [ItemModel] = []
    private var subscription: AnyCancellable?

    static let activeListKey = "watch.activeListId"

    init(sync: WatchSyncCoordinator, defaults: UserDefaults = .standard, widgets: WatchWidgetPublisher? = nil) {
        self.sync = sync
        self.defaults = defaults
        self.widgets = widgets
        subscription = sync.$revision.sink { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
        rebuild()
    }

    var isAllDone: Bool { totalCount > 0 && checkedCount == totalCount }
    var hasLists: Bool { !lists.isEmpty }

    /// Alles aus SwiftData neu lesen.
    func rebuild() {
        let models = ((try? sync.listStore.fetchLists()) ?? []).compactMap { $0.toListModel() }
        let active = resolveActiveList(models)
        activeListId = active?.id
        title = active?.title ?? "Famlist"
        lists = summaries(models)
        items = active.map(liveItems(of:)) ?? []
        sections = WatchSectionBuilder.sections(items, categories: sync.categories)
        totalCount = items.count
        checkedCount = items.filter(\.isChecked).count
        frequent = ItemCatalogEntry.frequentlyUsed(sync.catalog.store.entries ?? []).map(Self.frequentItem)
        pendingChanges = sync.engine.pendingOperations
        widgets?.publish(active == nil ? .empty
                         : WatchWidgetState(listName: title, open: totalCount - checkedCount, total: totalCount))
    }

    /// Anzeige des Screens „Artikel“.
    func detail(for itemId: String) -> WatchItemDetail? {
        guard let item = items.first(where: { $0.id == itemId }) else { return nil }
        return WatchItemDetail(id: item.id, name: item.name,
                               category: CategoryResolver.name(for: item.category, in: sync.categories),
                               unitName: WatchQuantity.unitName(measure: item.measure),
                               units: item.units, isChecked: item.isChecked)
    }

    // MARK: - Aufbau

    /// Gemerkte Liste, sonst Favorit, sonst Standardliste, sonst die älteste.
    private func resolveActiveList(_ models: [ListModel]) -> ListModel? {
        let stored = defaults.string(forKey: Self.activeListKey).flatMap(UUID.init(uuidString:))
        return models.first { $0.id == stored }
            ?? models.first { $0.id == sync.favoriteListId }
            ?? models.first(where: \.isDefault)
            ?? models.first
    }

    /// Favorit zuerst, dann alphabetisch.
    private func summaries(_ models: [ListModel]) -> [WatchListSummary] {
        models.map { list -> WatchListSummary in
            let listItems = liveItems(of: list)
            let open = listItems.filter { !$0.isChecked }.count
            let total = listItems.count
            return WatchListSummary(id: list.id, name: list.title,
                                    status: WatchSectionBuilder.status(open: open, total: total),
                                    fraction: total == 0 ? 0 : Double(total - open) / Double(total),
                                    isFavorite: list.id == sync.favoriteListId)
        }
        .sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Artikel einer Liste ohne Löschmarkierungen.
    func liveItems(of list: ListModel) -> [ItemModel] {
        ((try? sync.itemStore.fetchItems(listId: list.id)) ?? []).map { $0.toItemModel() }.filter { $0.tombstone != true }
    }

    /// Detailzeile unter „Oft gekauft“: Kategorie, sonst Einheit (Design: „Milchprodukte“ / „10 Stück“).
    private static func frequentItem(_ entry: ItemCatalogEntry) -> WatchFrequentItem {
        let category = entry.category?.trimmingCharacters(in: .whitespaces) ?? ""
        let detail = category.isEmpty ? (entry.measure.isEmpty ? "" : WatchQuantity.unitName(measure: entry.measure)) : category
        return WatchFrequentItem(name: entry.name, detail: detail)
    }
}
