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
        
        // 3. SERVER-SYNC (BATCH-UPDATE für minimale Overhead)
        // Erstelle ItemModels auf MainActor bevor wir in Background-Task gehen
        var itemModels: [ItemModel] = []
        for uuid in uuidsToUpdate {
            if let entity = try? itemStore.fetchItem(id: uuid) {
                itemModels.append(entity.toItemModel())
            }
        }
        
        // Capture dependencies for background task
        let repository = self.repository
        let currentListId = self.listId
        
        // Nutze Batch-Update um nur EINEN fetchAndYield-Call zu machen
        // Das Repository handled die Suppression von Realtime-Fetches intern
        do {
            try await repository.batchUpdateItems(itemModels, listId: currentListId)
        } catch {
            logVoid(params: (
                action: "toggleAllItems.batchSync.error",
                itemCount: itemModels.count,
                error: (error as NSError).localizedDescription
            ))
        }
        
        logVoid(params: (
            action: "toggleAllItems.completed",
            itemCount: uuidsToUpdate.count
        ))
        
        UserLog.Sync.completed(itemCount: uuidsToUpdate.count)
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
            switch order {
            case .category:
                // Gruppiere nach gecheckt/ungecheckt, dann nach Kategorie
                items.sort { item1, item2 in
                    if item1.isChecked != item2.isChecked {
                        return !item1.isChecked
                    }
                    let cat1 = item1.category ?? "Sonstiges"
                    let cat2 = item2.category ?? "Sonstiges"
                    if cat1 != cat2 {
                        return cat1 < cat2
                    }
                    return item1.name < item2.name
                }
                
            case .alphabetical:
                // Gruppiere nach gecheckt/ungecheckt, dann alphabetisch
                items.sort { item1, item2 in
                    if item1.isChecked != item2.isChecked {
                        return !item1.isChecked
                    }
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
                
            case .dateAdded:
                // Gruppiere nach gecheckt/ungecheckt, dann nach Erstellungsdatum (neueste zuerst)
                items.sort { item1, item2 in
                    if item1.isChecked != item2.isChecked {
                        return !item1.isChecked
                    }
                    // Verwende createdAt wenn vorhanden, sonst ID als Fallback
                    let date1 = item1.createdAt ?? Date.distantPast
                    let date2 = item2.createdAt ?? Date.distantPast
                    return date1 > date2
                }
            }
        }
    }
}

