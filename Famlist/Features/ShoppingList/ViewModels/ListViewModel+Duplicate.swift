/*
 ListViewModel+Duplicate.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Liste duplizieren“ aus dem Dock: legt eine neue Liste „<Titel> (Kopie)“ an
   und kopiert alle Artikel der aktiven Liste hinein.

 🔰 Notes for Beginners:
 - Die Liste selbst wird wie bei createNewList() remote angelegt (ListsRepository).
   Das erfordert eine Verbindung; offline schlägt der Schritt fehl und errorMessage wird gesetzt.
 - Die Artikel laufen danach offline-first über die SyncEngine: erst SwiftData, dann Warteschlange.
 - Kopien starten immer offen und verfügbar (isChecked = false, isUnavailable = false).
 - Die SyncEngine vergibt deterministische IDs aus (neue listId, Name) → keine Kollision mit dem Original.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {

    /// Duplicates the active list including all items and switches to the copy.
    func duplicateActiveList() {
        guard let source = defaultList else { return }
        duplicateList(source, ownerId: source.ownerId)
    }

    /// Listen-Optionen „Duplizieren“: kopiert eine beliebige Liste samt Artikeln (alle offen) und wechselt dorthin.
    /// - Parameter ownerId: Besitzer der Kopie (der aktuelle Nutzer – auch wenn die Quelle geteilt ist).
    func duplicateList(_ source: ListModel, ownerId: UUID) {
        guard let repo = listsRepository else { return }
        let sourceItems = source.id == listId
            ? items
            : ((try? itemStore.fetchItems(listId: source.id))?.map { $0.toItemModel() } ?? [])
        let newTitle = "\(source.title) (Kopie)"
        logVoid(params: (action: "duplicateList", sourceId: source.id, itemCount: sourceItems.count))

        Task { [weak self] in
            guard let self else { return }
            do {
                let row = try await repo.createList(for: ownerId, title: newTitle)
                let copy = ListModel(
                    id: row.id, ownerId: row.owner_id, title: row.title,
                    isDefault: row.is_default,
                    createdAt: row.created_at ?? Date(), updatedAt: row.updated_at ?? Date()
                )
                _ = try? listStore.upsert(model: copy)
                allLists.append(copy)
                listItemCounts[copy.id] = sourceItems.count
                UserLog.Data.listDuplicated(name: source.title, newName: copy.title, itemCount: sourceItems.count)
                switchToList(copy)
                await copyItems(sourceItems, into: copy.id)
                logVoid(params: (action: "duplicateList.success", newListId: copy.id))
            } catch {
                setError(error)
                logVoid(params: (action: "duplicateList.error", error: (error as NSError).localizedDescription))
            }
        }
    }

    /// Creates fresh copies of the given items in the target list via the SyncEngine.
    private func copyItems(_ sourceItems: [ItemModel], into listId: UUID) async {
        guard let syncEngine else { return }
        for item in sourceItems {
            let copy = ItemModel(
                imageData: item.imageData,
                name: item.name,
                units: item.units,
                measure: item.measure,
                price: item.price,
                category: item.category,
                productDescription: item.productDescription,
                brand: item.brand,
                listId: listId.uuidString,
                ownerPublicId: item.ownerPublicId
            )
            await syncEngine.createItem(copy)
            // Offline there is no remote snapshot → read the local store so the copy appears immediately.
            if self.listId == listId { refreshItemsFromStore() }
        }
    }
}
