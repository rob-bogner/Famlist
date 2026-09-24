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
 - Filter „Alle“ plus jede Kategorie des Nutzers, die im Artikelstamm vorkommt, in Ladenweg-Reihenfolge.

 📝 Last Change:
 - Schreibaufträge nacheinander; `load()` wartet auf sie (Änderungen gingen sonst beim Neuladen verloren).
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
    /// Letzter Schreibauftrag (Ändern/Löschen). Aufträge laufen nacheinander; `load()` wartet auf sie.
    private var writeTask: Task<Void, Never>?
    /// Zählt gestartete Schreibaufträge. Ändert sich der Wert während `load()`, wird neu geladen.
    private var writeCount = 0
    /// Kategorien des Nutzers (Filterchips in Ladenweg-Reihenfolge).
    var categories: [CategoryDefinition]

    init(repository: any ItemCatalogRepository, categories: [CategoryDefinition] = CategoryDefinition.defaults) {
        self.repository = repository
        self.categories = categories
    }

    /// „Alle“ + vorhandene Kategorien in Ladenweg-Reihenfolge.
    var filters: [String] {
        let present = Set(entries.map { CategoryResolver.name(for: $0.category, in: categories) })
        return [Self.allFilter] + categories.map(\.name).filter(present.contains)
    }

    /// Einträge nach Suche und Filter.
    var visibleEntries: [ItemCatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return entries.filter { entry in
            let matchesFilter = selectedFilter == Self.allFilter
                || CategoryResolver.name(for: entry.category, in: categories) == selectedFilter
            let matchesQuery = q.isEmpty || entry.name.lowercased().contains(q)
                || (entry.brand?.lowercased().contains(q) ?? false)
            return matchesFilter && matchesQuery
        }
    }

    /// Zweite Zeile einer Karte, z. B. „Kerrygold · 250 g“ oder „Sonstiges · 1 Packung“.
    static func meta(for entry: ItemCatalogEntry, categories: [CategoryDefinition] = CategoryDefinition.defaults) -> String {
        let lead = (entry.brand?.isEmpty == false ? entry.brand : nil) ?? CategoryResolver.name(for: entry.category, in: categories)
        guard !entry.measure.isEmpty else { return lead }
        return "\(lead) · 1 \(Measure.fromExternal(entry.measure).localizedName)"
    }

    /// Lädt erst, wenn alle Schreibaufträge beim Server angekommen sind. Sonst kann die Antwort
    /// den alten Stand enthalten und eine gerade gespeicherte Änderung in der Anzeige überschreiben.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var fetched: [ItemCatalogEntry]
            repeat {
                let before = writeCount
                await writeTask?.value
                fetched = try await repository.fetchAll()
                if before == writeCount { break }
            } while true
            entries = fetched
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
        enqueueWrite { [repository] in
            do {
                try await repository.delete(id: entry.id)
            } catch {
                self.entries.insert(entry, at: min(index, self.entries.count))
                self.errorMessage = "„\(entry.name)“ konnte nicht gelöscht werden."
            }
        }
    }

    func update(_ entry: ItemCatalogEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let previous = entries[index]
        entries[index] = entry
        UserLog.Data.catalogItemUpdated(name: entry.name)
        enqueueWrite { [repository] in
            do {
                try await repository.update(entry)
            } catch {
                if let i = self.entries.firstIndex(where: { $0.id == entry.id }) { self.entries[i] = previous }
                self.errorMessage = "„\(entry.name)“ konnte nicht gespeichert werden."
            }
        }
    }

    /// Hängt einen Schreibauftrag hinten an (Reihenfolge wie getippt, wie im CategoryStore).
    private func enqueueWrite(_ work: @escaping @MainActor () async -> Void) {
        writeCount += 1
        let previous = writeTask
        writeTask = Task {
            await previous?.value
            await work()
        }
    }
}
