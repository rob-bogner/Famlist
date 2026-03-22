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
 - Bulk Toggle und Sortier-Aktionen ausgelagert aus ListViewModel
 ------------------------------------------------------------------------
 */

import Foundation
import SwiftUI

// MARK: - Sort Order

/// Definiert die verfügbaren Sortieroptionen für die Einkaufsliste
enum SortOrder: String, CaseIterable {
    case category = "Kategorie"
    case alphabetical = "Alphabetisch"
    case dateAdded = "Datum"

    var displayName: String { rawValue }

    /// Sortiert ein Item-Array nach dieser SortOrder.
    /// Gecheckte Items werden immer hinter ungecheckte gestellt.
    /// - Parameter items: Das zu sortierende Array.
    /// - Returns: Neues, sortiertes Array.
    func apply(to items: [ItemModel]) -> [ItemModel] {
        switch self {
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
        for i in items.indices where itemIDsToUpdate.contains(items[i].id) {
            items[i].isChecked = targetState
        }
        
        // Convert String IDs to UUIDs once
        let uuidsToUpdate = itemIDsToUpdate.compactMap { UUID(uuidString: $0) }
        
        // 2. SWIFTDATA BATCH-UPDATE (single save at end)
        do {
            try itemStore.batchUpdateCheckedStatus(ids: uuidsToUpdate, isChecked: targetState)
        } catch {
            logVoid(params: (
                note: "toggleAllItems SwiftData batch error",
                itemCount: uuidsToUpdate.count,
                error: (error as NSError).localizedDescription
            ))
        }
        
        // P6 Schnitt A: HLC-Anreicherung vor dem Remote-Schreiben.
        // batchUpdateCheckedStatus() setzt isChecked und .pendingUpdate, aber keinen neuen HLC.
        // Ohne gültigen HLC verliert der Toggle-Payload jeden CRDT-Vergleich auf Empfänger-Geräten
        // (epoch=0 < jeder valider lokaler HLC → Remote-Toggle wird verworfen).
        // Lösung: neuen HLC via SyncEngine generieren und in SwiftData + ItemModel schreiben,
        // bevor batchUpdateItems() den Payload an Supabase schickt.
        if let syncEngine {
            for uuid in uuidsToUpdate {
                guard let entity = try? itemStore.fetchItem(id: uuid) else { continue }
                let newHLC = syncEngine.hlcForUpdate(
                    currentTimestamp: entity.hlcTimestamp,
                    currentCounter: entity.hlcCounter,
                    currentNodeId: entity.hlcNodeId
                )
                entity.hlcTimestamp    = newHLC.timestamp
                entity.hlcCounter     = newHLC.counter
                entity.hlcNodeId      = newHLC.nodeId
                entity.lastModifiedBy = newHLC.nodeId  // nodeId == lastModifiedBy per SyncEngine-Konvention
            }
            try? itemStore.save()
        }

        // 3. SERVER-SYNC: single bulk upsert statt N paralleler .update() calls (P6 Schnitt B).
        // Erstelle ItemModels auf MainActor bevor wir in Background-Task gehen.
        var itemModels: [ItemModel] = []
        for uuid in uuidsToUpdate {
            if let entity = try? itemStore.fetchItem(id: uuid) {
                itemModels.append(entity.toItemModel())
            }
        }

        // Capture dependencies for background task
        let repository = self.repository
        let currentListId = self.listId

        do {
            try await repository.bulkToggleItems(itemModels, listId: currentListId)
        } catch {
            logVoid(params: (
                action: "toggleAllItems.bulkUpsert.error",
                itemCount: itemModels.count,
                error: (error as NSError).localizedDescription
            ))
            // Fallback: enqueue individual update operations so the existing
            // retry/backoff mechanism picks them up. SwiftData already has the
            // correct state (.pendingUpdate + valid HLC); only the HTTP push failed.
            if let syncEngine {
                await syncEngine.enqueueBulkToggleFallback(itemModels)
                logVoid(params: (
                    action: "toggleAllItems.fallbackQueued",
                    itemCount: itemModels.count
                ))
            }
        }
        
        logVoid(params: (action: "toggleAllItems.completed", itemCount: uuidsToUpdate.count))
        
        UserLog.Sync.completed(itemCount: uuidsToUpdate.count)
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

        // Tombstone all items locally in a single batch commit, then queue remote ops.
        // isBulkDeleting suppresses per-item refreshItemsFromStore() inside the loop.
        isBulkDeleting = true
        snapshot.forEach { deleteItem($0) }
        isBulkDeleting = false

        // Single consolidated UI refresh from SwiftData. Items are now soft-deleted
        // (deletedAt set by setSyncStatus(.pendingDelete)), so fetchItems(includeDeleted:false)
        // excludes them. This also clears pendingBulkDeleteIDs via intersection.
        refreshItemsFromStore()

        // Gate off — stream handler and pagination can resume.
        isBulkMutationActive = false
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
        isBulkDeleting = true
        toDelete.forEach { deleteItem($0) }
        isBulkDeleting = false
        refreshItemsFromStore()
        isBulkMutationActive = false
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
        isBulkDeleting = true
        toDelete.forEach { deleteItem($0) }
        isBulkDeleting = false
        refreshItemsFromStore()
        isBulkMutationActive = false
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
    
    /// Setzt die Sortierreihenfolge und sortiert die Items entsprechend
    func setSortOrder(_ order: SortOrder) {
        ListViewModel.currentSortOrder = order
        sortItems(by: order)
        
        logVoid(params: (
            action: "setSortOrder",
            order: order.rawValue
        ))
    }
    
    /// Sortiert die Items nach der angegebenen Reihenfolge
    private func sortItems(by order: SortOrder) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            items = order.apply(to: items)
        }
    }
}

