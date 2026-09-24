/*
 ManageItemsViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand für „Artikel verwalten“: alle Einträge des Artikelstamms (item_catalog),
   Suche, Kategorie-Filterchips, Bearbeiten und Löschen.

 🔰 Notes for Beginners:
 - Der Artikelstamm liegt nur in Supabase (siehe PLAN.md, Risiko R3). Löschen wird optimistisch
   angezeigt und bei einem Fehler zurückgenommen.
 - Filter „Alle“ plus jede Kategorie, die im Artikelstamm vorkommt, in Ladenweg-Reihenfolge.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ManageItemsViewModel: ObservableObject {
    static let allFilter = "Alle"

    @Published private(set) var entries: [ItemCatalogEntry] = []
    @Published var query = ""
    @Published var selectedFilter = ManageItemsViewModel.allFilter
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: any ItemCatalogRepository

    init(repository: any ItemCatalogRepository) {
        self.repository = repository
    }

    /// „Alle“ + vorhandene Kategorien in Ladenweg-Reihenfolge.
    var filters: [String] {
        let present = Set(entries.map { ItemCategory.from($0.category) })
        return [Self.allFilter] + ItemCategory.displayOrder.filter(present.contains).map(\.rawValue)
    }

    /// Einträge nach Suche und Filter.
    var visibleEntries: [ItemCatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return entries.filter { entry in
            let matchesFilter = selectedFilter == Self.allFilter
                || ItemCategory.from(entry.category).rawValue == selectedFilter
            let matchesQuery = q.isEmpty || entry.name.lowercased().contains(q)
                || (entry.brand?.lowercased().contains(q) ?? false)
            return matchesFilter && matchesQuery
        }
    }

    /// Zweite Zeile einer Karte, z. B. „Kerrygold · 250 g“ oder „Sonstiges · 1 Packung“.
    static func meta(for entry: ItemCatalogEntry) -> String {
        let lead = (entry.brand?.isEmpty == false ? entry.brand : nil) ?? ItemCategory.from(entry.category).rawValue
        guard !entry.measure.isEmpty else { return lead }
        return "\(lead) · 1 \(Measure.fromExternal(entry.measure).localizedName)"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await repository.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = "Artikel konnten nicht geladen werden."
            logVoid(params: (action: "manageItems.load.error", error: (error as NSError).localizedDescription))
        }
    }

    func delete(_ entry: ItemCatalogEntry) {
        guard let index = entries.firstIndex(of: entry) else { return }
        entries.remove(at: index)
        UserLog.Data.catalogItemDeleted(name: entry.name)
        Task {
            do {
                try await repository.delete(id: entry.id)
            } catch {
                entries.insert(entry, at: min(index, entries.count))
                errorMessage = "„\(entry.name)“ konnte nicht gelöscht werden."
            }
        }
    }

    func update(_ entry: ItemCatalogEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let previous = entries[index]
        entries[index] = entry
        UserLog.Data.catalogItemUpdated(name: entry.name)
        Task {
            do {
                try await repository.update(entry)
            } catch {
                if let i = entries.firstIndex(where: { $0.id == entry.id }) { entries[i] = previous }
                errorMessage = "„\(entry.name)“ konnte nicht gespeichert werden."
            }
        }
    }
}
