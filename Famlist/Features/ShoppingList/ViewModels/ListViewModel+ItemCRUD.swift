/*
 ListViewModel+ItemCRUD.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel anlegen, bearbeiten, umbenennen, löschen, erneut senden und abhaken (Offline-First über die SyncEngine).

 📝 Last Change:
 - Aus ListViewModel.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    // MARK: - CRUD Operations
    
    /// Adds a new item after normalizing fields (e.g., measure, listId).
    /// - Parameter barcode: EAN/UPC aus dem Barcode-Scanner; wird im Artikelstamm gemerkt.
    func addItem(_ item: ItemModel, barcode: String? = nil) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString

        // Duplikat-Check: existiert bereits ein ungehacktes Item mit gleichem Namen?
        if let existingIndex = items.firstIndex(where: {
            ItemIdentity.normalizedKey($0.name) == ItemIdentity.normalizedKey(normalized.name) && !$0.isChecked
        }) {
            incrementExisting(at: existingIndex, with: normalized)
            return
        }

        // Endgültige ID sofort bestimmen – die sofort angezeigte Karte und der gespeicherte Artikel
        // haben dieselbe ID (vorher: Zufalls-ID, später ersetzt → doppelte Einträge möglich).
        if let listUUID = UUID(uuidString: normalized.listId ?? "") {
            normalized = normalized.withId(ItemIdentity.newItemId(name: normalized.name, listId: listUUID, store: itemStore).uuidString)
        }

        let displayName = [normalized.brand, normalized.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        UserLog.Data.itemAdded(
            name: displayName.isEmpty ? "Artikel" : displayName,
            units: normalized.units,
            measure: normalized.measure
        )

        saveToCatalog(normalized, barcode: barcode)

        // Gerade weggewischt und noch im Rückgängig-Zeitraum? Dann erst die Löschung festschreiben und
        // danach neu anlegen – beides in dieser Reihenfolge, damit das Anlegen die neuere HLC bekommt.
        // Vorher verschwand der neu hinzugefügte Artikel nach 5 s wieder (Audit H2).
        let pendingDeleteTask = pendingBulkDeleteIDs.contains(normalized.id) ? commitPendingDeletion() : nil

        items.append(normalized)                 // Sofort sichtbar (Offline-First)

        guard let syncEngine else { return }
        let toCreate = normalized
        Task {
            await pendingDeleteTask?.value
            await syncEngine.createItem(toCreate)
            self.refreshItemsFromStore()
        }
    }

    /// Duplikat hinzugefügt: Menge des vorhandenen Artikels erhöhen und fehlende Angaben ergänzen.
    private func incrementExisting(at index: Int, with added: ItemModel) {
        var incremented = items[index]
        let oldUnits = incremented.units
        incremented.units = oldUnits + max(added.units, 1)
        incremented = ListViewModel.fillingMissingFields(of: incremented, from: added)
        logVoid(params: (action: "addItem.increment", itemId: incremented.id, from: oldUnits, to: incremented.units))
        UserLog.Data.itemCountIncremented(name: incremented.name, from: oldUnits, to: incremented.units,
                                          measure: incremented.measure)
        items[index] = incremented
        updateItem(incremented, suppressUserLog: true)
    }

    /// Artikelstamm im Hintergrund ergänzen (blockiert die Liste nicht).
    private func saveToCatalog(_ item: ItemModel, barcode: String?) {
        guard let catalogRepo = catalogRepository else { return }
        var catalogEntry = ItemCatalogEntry.from(item: item, ownerPublicId: "")
        catalogEntry.barcode = barcode
        Task {
            do {
                try await catalogRepo.save(catalogEntry)
            } catch {
                logVoid(params: (action: "catalogSave.failed", itemName: item.name, error: (error as NSError).localizedDescription))
            }
        }
    }
    
    /// Updates an existing item after normalizing fields.
    /// - Parameter suppressUserLog: Pass `true` when the caller has already logged the action
    ///   (e.g. `toggleItemChecked`, increment path in `addItem`) to avoid duplicate logs.
    /// - Parameter updateCatalog: false, wenn die Änderung aus dem Artikelstamm kommt (dort schon gespeichert).
    func updateItem(_ item: ItemModel, trackPendingAnimation: Bool = false, suppressUserLog: Bool = false,
                    updateCatalog: Bool = true) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString

        // Umbenennen: Die ID hängt am Namen. Alten Artikel löschen, neuen anlegen (ADR-005) – sonst würde
        // späteres Hinzufügen des alten Namens den umbenannten Artikel überschreiben (Audit H3).
        if let old = currentItem(id: normalized.id),
           ItemIdentity.normalizedKey(old.name) != ItemIdentity.normalizedKey(normalized.name) {
            renameItem(from: old, to: normalized, updateCatalog: updateCatalog)
            return
        }

        logVoid(params: (
            action: "updateItem",
            itemId: normalized.id,
            brand: normalized.brand ?? "nil",
            category: normalized.category ?? "nil",
            description: normalized.productDescription ?? "nil"
        ))

        if !suppressUserLog {
            let displayName = [normalized.brand, normalized.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let resolvedName = displayName.isEmpty ? "Artikel" : displayName
            // Detect quantity change by comparing with current items snapshot (still holds old state at call time).
            if let oldItem = items.first(where: { $0.id == normalized.id }), oldItem.units != normalized.units {
                UserLog.Data.itemQuantityChanged(
                    name: resolvedName,
                    from: oldItem.units,
                    to: normalized.units,
                    measure: normalized.measure
                )
            } else {
                UserLog.Data.itemUpdated(name: resolvedName)
            }
        }

        // Update personal item catalog (fire-and-forget; keeps catalog in sync with edits)
        if updateCatalog, let catalogRepo = catalogRepository {
            let catalogEntry = ItemCatalogEntry.from(item: normalized, ownerPublicId: "")
            Task {
                do {
                    try await catalogRepo.save(catalogEntry)
                    logVoid(params: (action: "catalogUpdate.success", itemName: normalized.name))
                } catch {
                    logVoid(params: (action: "catalogUpdate.failed", itemName: normalized.name, error: (error as NSError).localizedDescription))
                }
            }
        }

        // Offline-First: Bearbeitung sofort in `items` sichtbar machen. Vorher kam die Änderung erst
        // nach `syncEngine.updateItem` (inkl. Netzwerk-Queue) über refreshItemsFromStore an – bei langsamer
        // oder fehlender Verbindung zeigte „Artikel bearbeiten“ deshalb weiter den alten Preis (0,00).
        applyLocalEdit(normalized)

        // Track animation state if requested.
        if trackPendingAnimation {
            pendingAnimatedItemIDs.insert(normalized.id)
        }
        
        guard let syncEngine else {
            if trackPendingAnimation { pendingAnimatedItemIDs.remove(normalized.id) }
            return
        }
        Task {
            await syncEngine.updateItem(normalized)
            await MainActor.run {
                // Refresh UI from SwiftData so the edit (e.g. price change) is immediately visible
                // without waiting for a Realtime echo. storeLocally() already wrote the correct
                // value; this call propagates it to self.items.
                self.refreshItemsFromStore()
                if trackPendingAnimation {
                    self.pendingAnimatedItemIDs.remove(normalized.id)
                }
            }
        }
    }
    
    /// Übernimmt die bearbeitbaren Felder sofort in `items`; CRDT-/Sync-Felder bleiben unverändert.
    private func applyLocalEdit(_ edited: ItemModel) {
        guard let index = items.firstIndex(where: { $0.id == edited.id }) else { return }
        var current = items[index]
        current.name = edited.name
        current.units = edited.units
        current.measure = edited.measure
        current.price = edited.price
        current.isChecked = edited.isChecked
        current.isUnavailable = edited.isUnavailable
        current.category = edited.category
        current.productDescription = edited.productDescription
        current.brand = edited.brand
        current.imageData = edited.imageData
        items[index] = current
    }

    /// Deletes an item (tombstone via SyncEngine). Auch nie gesendete Artikel laufen über die Engine:
    /// Die ersetzte Anlage-Operation fällt dabei weg, und die Löschung erreicht alle Geräte.
    func deleteItem(_ item: ItemModel) {
        if !isBulkDeleting {
            let displayName = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            UserLog.Data.itemDeleted(
                name: displayName.isEmpty ? "Artikel" : displayName,
                units: item.units,
                measure: item.measure
            )
        }
        items.removeAll { $0.id == item.id }
        guard let syncEngine else { return }
        Task { await syncEngine.deleteItem(item) }
    }
    
    /// Re-queues a permanently-failed item for sync.
    func retryItem(_ item: ItemModel) {
        Task { await syncEngine?.retryItem(item) }
    }

    /// Toggles the checked state of an item and persists the change via updateItem.
    /// Uses optimistic update: UI changes immediately for instant feedback, then syncs to backend.
    func toggleItemChecked(_ item: ItemModel) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let wasComplete = isShoppingComplete
        defer { noteCheckChange(wasComplete: wasComplete) }

        // Optimistic update: toggle in-place, then re-sort according to currentSortOrder.
        // This prevents "double jump" and keeps the order consistent with any remote snapshots.
        var updatedItem = items[index]
        updatedItem.isChecked.toggle()
        items[index] = updatedItem
        items = ListViewModel.currentSortOrder.apply(to: items)

        // Specific check/uncheck log — suppresses generic "bearbeitet" in updateItem.
        let displayName = [item.brand, item.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        let resolvedName = displayName.isEmpty ? "Artikel" : displayName
        if updatedItem.isChecked {
            UserLog.Data.itemChecked(name: resolvedName, units: updatedItem.units, measure: updatedItem.measure)
        } else {
            UserLog.Data.itemUnchecked(name: resolvedName, units: updatedItem.units, measure: updatedItem.measure)
        }

        pendingAnimatedItemIDs.insert(updatedItem.id)
        // Abhaken ändert den Artikelstamm nicht (vorher: alter Preis/Foto überschrieb den Stamm, Audit H7).
        updateItem(updatedItem, trackPendingAnimation: true, suppressUserLog: true, updateCatalog: false)
    }
    
    /// Aktueller Stand eines Artikels: aus der Anzeige, sonst aus SwiftData.
    internal func currentItem(id: String) -> ItemModel? {
        if let shown = items.first(where: { $0.id == id }) { return shown }
        guard let uuid = UUID(uuidString: id), let entity = (try? itemStore.fetchItem(id: uuid)) ?? nil,
              entity.tombstone != true else { return nil }
        return entity.toItemModel()
    }

    /// Umbenennen = alten Artikel löschen + unter der ID des neuen Namens anlegen.
    /// Existiert der neue Name schon als eigener Artikel, bekommt der umbenannte eine eigene ID
    /// (kein stilles Überschreiben des vorhandenen Artikels).
    private func renameItem(from old: ItemModel, to edited: ItemModel, updateCatalog: Bool) {
        guard let listUUID = UUID(uuidString: edited.listId ?? "") else { return }
        let target = UUID.deterministicItemID(listId: listUUID, name: edited.name)
        let targetEntity = (try? itemStore.fetchItem(id: target)) ?? nil
        let targetIsLive = targetEntity != nil && targetEntity?.tombstone != true
        let renamed = edited.withId((targetIsLive ? UUID() : target).uuidString)
        logVoid(params: (action: "renameItem", from: old.id, to: renamed.id))
        UserLog.Data.itemUpdated(name: renamed.name)
        if updateCatalog { saveToCatalog(renamed, barcode: nil) }
        if let index = items.firstIndex(where: { $0.id == old.id }) { items[index] = renamed }
        guard let syncEngine else { return }
        Task {
            await syncEngine.deleteItem(old)
            await syncEngine.updateItem(renamed)      // legt unter der neuen ID an
            self.refreshItemsFromStore()
        }
    }
}

// MARK: - Measure Canonicalization

private extension ListViewModel {
    /// Converts a free-form measure string to a normalized token using the Measure enum.
    func canonicalizeMeasure(_ raw: String) -> String {
        MeasureCanonicalizer.canonicalize(raw)
    }
}
