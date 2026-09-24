/*
 ListSectionBuilder.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Baut aus Artikeln, Sortier-Einstellung und Tab-Filter die Abschnitte der Liste.

 🔰 Notes for Beginners:
 - Reine Funktion ohne Zustand → einfach zu testen (ListSectionBuilderTests).
 - „Nach Kategorie“: Gruppen in Ladenweg-Reihenfolge, darin alphabetisch.
   „Alphabetisch“ / „Zuletzt hinzugefügt“ / „Manuell“: eine flache Liste ohne Kopf.
 - „Erledigte nach unten“ an: abgehakte Artikel stehen im eigenen Abschnitt „Abgehakt“ ganz unten.
   Aus: sie bleiben an ihrer Stelle in der Gruppe bzw. der flachen Liste.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Sortieren).
 ------------------------------------------------------------------------
 */

import Foundation

/// Pure builder turning items + sort settings into list sections.
enum ListSectionBuilder {
    static func sections(items: [ItemModel],
                         settings: ListSortSettings,
                         filter: ItemFilter,
                         manualOrder: [String] = [],
                         categoryOrder: [ItemCategory] = ItemCategory.displayOrder) -> [ListSection] {
        let visible = items.filter { $0.isChecked ? filter.showsCheckedItems : filter.showsOpenItems }
        let open = visible.filter { !$0.isChecked }
        let checked = visible.filter(\.isChecked)
        let main = settings.doneAtBottom ? open : visible

        var result: [ListSection]
        if settings.order == .category {
            result = categorySections(main, order: categoryOrder)
        } else {
            let sorted = sortFlat(main, order: settings.order, manualOrder: manualOrder)
            result = sorted.isEmpty ? [] : [ListSection(kind: .flat, items: sorted)]
        }
        if settings.doneAtBottom, !checked.isEmpty {
            let sortedChecked = settings.order == .category
                ? checked.sorted(by: byName)
                : sortFlat(checked, order: settings.order, manualOrder: manualOrder)
            result.append(ListSection(kind: .checked, items: sortedChecked))
        }
        return result
    }

    private static func categorySections(_ items: [ItemModel], order: [ItemCategory]) -> [ListSection] {
        let grouped = Dictionary(grouping: items) { ItemCategory.from($0.category) }
        return order.compactMap { category in
            guard let group = grouped[category], !group.isEmpty else { return nil }
            return ListSection(kind: .category(category), items: group.sorted(by: byName))
        }
    }

    /// Flache Sortierung ohne Trennung offen/erledigt (die übernimmt `doneAtBottom`).
    private static func sortFlat(_ items: [ItemModel], order: SortOrder, manualOrder: [String]) -> [ItemModel] {
        switch order {
        case .category, .alphabetical:
            return items.sorted(by: byName)
        case .dateAdded:
            return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .manual:
            let rank = Dictionary(manualOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            return items.sorted { lhs, rhs in
                switch (rank[lhs.id], rank[rhs.id]) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
                }
            }
        }
    }

    private static func byName(_ lhs: ItemModel, _ rhs: ItemModel) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
