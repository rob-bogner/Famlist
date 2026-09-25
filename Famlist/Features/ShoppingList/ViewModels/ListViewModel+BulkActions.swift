/*
 ListViewModel+BulkActions.swift
 
 Famlist
 Created on: 22.11.2025
 
 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension für Bulk-Aktionen und Sortierung auf der Shopping-Liste.
 
 🛠 Includes:
 - Toggle all items (check/uncheck all)
 - Sort order management
 
 🔰 Notes for Beginners:
 - Diese Extension trennt Bulk-Operationen vom Core ViewModel
 - Alle Methoden sind @MainActor für Thread-Sicherheit
 - Sortierung wird optimistisch auf dem UI angewendet
 
 📝 Last Change:
 - „Alle abhaken“ und Massenlöschen laufen gebündelt über die SyncEngine (Audit 25.09.2026, K3).
 ------------------------------------------------------------------------
 */

import Foundation
import SwiftUI

// MARK: - Sort Order

/// Definiert die verfügbaren Sortieroptionen für die Einkaufsliste
enum SortOrder: String, CaseIterable, Codable {
    case category = "Kategorie"
    case alphabetical = "Alphabetisch"
    case dateAdded = "Datum"
    /// Reihenfolge per Ziehen; die Reihenfolge liegt lokal in `ManualOrderStore`.
    case manual = "Manuell"

    var displayName: String { rawValue }

    /// Sortiert ein Item-Array nach dieser SortOrder.
    /// Gecheckte Items werden immer hinter ungecheckte gestellt.
    /// - Parameter items: Das zu sortierende Array.
    /// - Returns: Neues, sortiertes Array.
    func apply(to items: [ItemModel], manualOrder: [String] = []) -> [ItemModel] {
        switch self {
        case .manual:
            // Unbekannte (neue) Artikel stehen hinter den angeordneten, neueste zuerst.
            let rank = Dictionary(manualOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            return items.sorted { item1, item2 in
                if item1.isChecked != item2.isChecked { return !item1.isChecked }
                switch (rank[item1.id], rank[item2.id]) {
                case let (r1?, r2?): return r1 < r2
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return (item1.createdAt ?? .distantPast) > (item2.createdAt ?? .distantPast)
                }
            }
        case .category:
            return items.sorted { item1, item2 in
                if item1.isChecked != item2.isChecked { return !item1.isChecked }
                let cat1 = item1.category ?? "Sonstiges"
                let cat2 = item2.category ?? "Sonstiges"
                if cat1 != cat2 { return cat1 < cat2 }
                return item1.name < item2.name
            }
        case .alphabetical:
            return items.sorted { item1, item2 in
                if item1.isChecked != item2.isChecked { return !item1.isChecked }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .dateAdded:
            return items.sorted { item1, item2 in
                if item1.isChecked != item2.isChecked { return !item1.isChecked }
                let date1 = item1.createdAt ?? Date.distantPast
                let date2 = item2.createdAt ?? Date.distantPast
                return date1 > date2
            }
        }
    }
}

// MARK: - Bulk Actions Extension

extension ListViewModel {
    
    // MARK: - Published Sort State
    
    /// Aktuelle Sortierreihenfolge (kann später als @Published im Hauptfile hinzugefügt werden)
    static var currentSortOrder: SortOrder = .category
    
    // MARK: - Toggle All Items
    
    /// Markiert alle Items als gecheckt oder ungecheckt, abhängig vom aktuellen Zustand.
    /// Optimiert für große Listen mit Debouncing, Batch-Updates und Chunked-Sync.
    func toggleAllItems() {
        // Cancel any pending toggle operation
        toggleAllDebounceTask?.cancel()
        
        // Debounce rapid repeated calls (50ms)
        toggleAllDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            await performToggleAll()
        }
    }
    
    /// Internal implementation of toggle all with optimized batch processing.
    private func performToggleAll() async {
        let allChecked = items.allSatisfy { $0.isChecked }
        let targetState = !allChecked
        
        // Sammle IDs der zu aktualisierenden Items
        let itemIDsToUpdate = items.filter { $0.isChecked != targetState }.map { $0.id }
        
        guard !itemIDsToUpdate.isEmpty else { return }
        
        logVoid(params: (
            action: "toggleAllItems.start",
            targetState: targetState,
            itemCount: itemIDsToUpdate.count
        ))
        
        // User-friendly log
        if targetState {
            UserLog.Data.allItemsChecked(count: itemIDsToUpdate.count)
        } else {
            UserLog.Data.allItemsUnchecked(count: itemIDsToUpdate.count)
        }
        
        // 1. LOKALES ARRAY SOFORT AKTUALISIEREN (nur gefilterte Items)
        let wasComplete = isShoppingComplete
        for i in items.indices where itemIDsToUpdate.contains(items[i].id) {
            items[i].isChecked = targetState
        }
        noteCheckChange(wasComplete: wasComplete)
        
        // 2. Lokal speichern, einreihen und gebündelt senden – über die SyncEngine mit neuer HLC.
        // Vorher: direkter Server-Aufruf ohne HLC und ohne Warteschlange → offline verloren, und die
        // Artikel blieben für immer „wartet auf Sync“ (übernahmen keine Änderungen der Familie mehr).
        let changed = items.filter { itemIDsToUpdate.contains($0.id) }
        await syncEngine?.applyLocalChanges(changed)

        logVoid(params: (action: "toggleAllItems.completed", itemCount: changed.count))
    }
    
    // MARK: - Bulk Delete

    /// Löscht alle Artikel der aktuellen Liste.
    ///
    /// UI-Strategie:
    /// 1. IDs als `pendingBulkDeleteIDs` registrieren (schützt gegen Realtime/Async-Reinjection)
    /// 2. `items` sofort leeren (einmaliger atomarer SwiftUI-Re-Render)
    /// 3. `isBulkDeleting` supprimiert per-Item-Refreshes während der forEach-Schleife
    /// 4. Finales `refreshItemsFromStore()` bereinigt `pendingBulkDeleteIDs` für bereits entfernte Items
    func deleteAllItems() {
        let snapshot = items
        guard !snapshot.isEmpty else { return }
        logVoid(params: (action: "deleteAllItems", count: snapshot.count))
        UserLog.Data.allItemsDeleted(count: snapshot.count)

        // --- Atomic UI transition: before-bulk → after-bulk, no intermediate states ---
        isBulkMutationActive = true
        pendingBulkDeleteIDs.formUnion(snapshot.map { $0.id })
        items = []
        // Reset pagination — all items gone, cursor is stale.
        currentCursor = nil
        PaginationCursor.clear(listId: listId)
        hasMoreItems = true
        isLoadingNextPage = false
        consecutiveEmptyPages = 0

        deleteInOneBatch(snapshot)
    }

    /// Löscht alle abgehakten Artikel der aktuellen Liste.
    func deleteCheckedItems() {
        let toDelete = items.filter { $0.isChecked }
        guard !toDelete.isEmpty else { return }
        logVoid(params: (action: "deleteCheckedItems", count: toDelete.count))
        UserLog.Data.checkedItemsDeleted(items: toDelete.map { ($0.name, $0.units, $0.measure) })

        isBulkMutationActive = true
        pendingBulkDeleteIDs.formUnion(toDelete.map { $0.id })
        items = items.filter { !$0.isChecked }
        deleteInOneBatch(toDelete)
    }

    /// Löscht alle nicht abgehakten Artikel der aktuellen Liste.
    func deleteUncheckedItems() {
        let toDelete = items.filter { !$0.isChecked }
        guard !toDelete.isEmpty else { return }
        logVoid(params: (action: "deleteUncheckedItems", count: toDelete.count))
        UserLog.Data.uncheckedItemsDeleted(items: toDelete.map { ($0.name, $0.units, $0.measure) })

        isBulkMutationActive = true
        pendingBulkDeleteIDs.formUnion(toDelete.map { $0.id })
        items = items.filter { $0.isChecked }
        deleteInOneBatch(toDelete)
    }

    /// Löschmarkierungen für mehrere Artikel in EINEM Speichervorgang und einem Sende-Durchlauf.
    internal func deleteInOneBatch(_ targets: [ItemModel]) {
        guard let syncEngine else {
            isBulkMutationActive = false
            return
        }
        Task {
            await syncEngine.deleteItems(targets)
            self.isBulkMutationActive = false
            self.refreshItemsFromStore()
        }
    }

    // MARK: - Bulk Import

    /// Applies a batch of merged import targets from the clipboard import flow.
    ///
    /// Writes are handled by SyncEngine.applyBulkItems() which issues a single save()
    /// and enqueues one operation per target — no per-item processQueue().
    /// UI is refreshed once after all writes complete.
    func applyBulkImport(_ result: ImportMergeService.MergeResult) {
        guard let syncEngine else { return }
        guard !result.targets.isEmpty else { return }

        isBulkMutationActive = true

        // Count targets for summary — no individual logs during import.
        var added = 0, reactivated = 0, incremented = 0
        for target in result.targets {
            switch target {
            case .createNew: added += 1
            case .reactivate: reactivated += 1
            case .update: incremented += 1
            }
        }

        let lvm = self

        Task {
            await syncEngine.applyBulkItems(result.targets)

            await MainActor.run {
                lvm.refreshItemsFromStore()
                lvm.isBulkMutationActive = false
                // Summary log after UI is updated — kein Einzel-Spam während des Imports.
                UserLog.Data.bulkImportCompleted(added: added, reactivated: reactivated, incremented: incremented)
            }

            await syncEngine.resumeSync()
        }
    }

    // MARK: - Sorting

    /// Setzt den Sortier-Modus der aktiven Liste und speichert ihn (Dock „Sortieren“).
    func setSortOrder(_ order: SortOrder) {
        var settings = sortSettings
        settings.order = order
        applySortSettings(settings)
        logVoid(params: (action: "setSortOrder", order: order.rawValue))
    }

    /// Schalter „Erledigte nach unten“ der aktiven Liste.
    func setDoneAtBottom(_ enabled: Bool) {
        var settings = sortSettings
        settings.doneAtBottom = enabled
        applySortSettings(settings)
        logVoid(params: (action: "setDoneAtBottom", enabled: enabled))
    }

    private func applySortSettings(_ settings: ListSortSettings) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sortSettings = settings
        }
        settings.save(listId: listId)
    }
}

