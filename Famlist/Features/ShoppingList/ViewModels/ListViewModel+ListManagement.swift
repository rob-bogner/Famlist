/*
 ListViewModel+ListManagement.swift

 Famlist
 Created on: 13.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - List management operations: load all lists, create, rename, delete, set default.
 - Implements FAM-34 (list overview) and FAM-35 (list management).

 🛠 Includes:
 - loadAllLists(ownerId:): Fetches all lists from repository and counts local items.
 - createNewList(title:ownerId:): Creates a new list and appends it to allLists.
 - renameList(_:to:): Optimistic rename with rollback on remote failure.
 - deleteList(_:): Soft-deletes locally, hard-deletes remotely (DB cascade on items).
 - setDefaultList(_:): Clears previous default, sets new one optimistically.
 - switchToList(_:): Wraps switchList(to:) and updates defaultList.

 🔰 Notes for Beginners:
 - All methods follow the Offline-First pattern: local write → remote sync.
 - @MainActor ensures all @Published mutations happen on the UI thread.

 📝 Last Change:
 - Initial creation for FAM-34 & FAM-35.
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {

    // MARK: - Load All Lists

    /// Fetches all lists for the given owner from the repository, counts local items, and updates allLists.
    func loadAllLists(ownerId: UUID) {
        guard let repo = listsRepository else { return }
        logVoid(params: (action: "loadAllLists", ownerId: ownerId))
        Task { [weak self] in
            guard let self else { return }
            do {
                let lists = try await repo.fetchAllLists(for: ownerId)
                await MainActor.run {
                    for list in lists {
                        _ = try? self.listStore.upsert(model: list)
                    }
                    var counts: [UUID: Int] = [:]
                    for list in lists {
                        counts[list.id] = (try? self.itemStore.fetchItems(listId: list.id))?.count ?? 0
                    }
                    self.allLists = lists
                    self.listItemCounts = counts
                    UserLog.Data.listsLoaded(count: lists.count)
                    logVoid(params: (action: "loadAllLists.success", count: lists.count))
                }
            } catch {
                await MainActor.run {
                    logVoid(params: (action: "loadAllLists.error", error: (error as NSError).localizedDescription))
                }
            }
        }
    }

    // MARK: - Create New List

    /// Creates a new list remotely and appends it to allLists.
    func createNewList(title: String, ownerId: UUID) {
        guard let repo = listsRepository else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        logVoid(params: (action: "createNewList", title: trimmed))
        Task { [weak self] in
            guard let self else { return }
            do {
                let row = try await repo.createList(for: ownerId, title: trimmed)
                let model = ListModel(
                    id: row.id, ownerId: row.owner_id, title: row.title,
                    isDefault: row.is_default,
                    createdAt: row.created_at ?? Date(), updatedAt: row.updated_at ?? Date()
                )
                await MainActor.run {
                    _ = try? self.listStore.upsert(model: model)
                    self.allLists.append(model)
                    self.listItemCounts[model.id] = 0
                    UserLog.Data.listCreated(name: model.title)
                    logVoid(params: (action: "createNewList.success", id: model.id))
                }
            } catch {
                await MainActor.run {
                    self.setError(error)
                    logVoid(params: (action: "createNewList.error", error: (error as NSError).localizedDescription))
                }
            }
        }
    }

    // MARK: - Rename List

    /// Optimistically renames a list locally and syncs to remote. Rolls back on failure.
    func renameList(_ list: ListModel, to newTitle: String) {
        guard let repo = listsRepository else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        logVoid(params: (action: "renameList", listId: list.id, from: list.title, to: trimmed))

        // Optimistic local update
        applyLocalListTitle(listId: list.id, title: trimmed)
        UserLog.Data.listRenamed(oldName: list.title, newName: trimmed)

        Task { [weak self] in
            guard let self else { return }
            do {
                let updated = try await repo.renameList(listId: list.id, title: trimmed)
                await MainActor.run {
                    _ = try? self.listStore.upsert(model: updated)
                    // In-place update — funktioniert für owned + member lists.
                    // refreshAllListsFromStore(ownerId:) würde Member-Listen herausfiltern
                    // da SwiftData nur nach owner_id sucht (FAM-21, bekannte Einschränkung).
                    if let idx = self.allLists.firstIndex(where: { $0.id == list.id }) {
                        self.allLists[idx] = updated
                    }
                    if self.defaultList?.id == list.id { self.defaultList = updated }
                    logVoid(params: (action: "renameList.success", listId: list.id))
                }
            } catch {
                await MainActor.run {
                    // Rollback: restore previous title
                    self.applyLocalListTitle(listId: list.id, title: list.title)
                    self.setError(error)
                    logVoid(params: (action: "renameList.error", error: (error as NSError).localizedDescription))
                }
            }
        }
    }

    // MARK: - Delete List

    /// Soft-deletes the list locally, removes it from allLists, and hard-deletes remotely (DB CASCADE).
    /// Prevents deleting the last list.
    func deleteList(_ list: ListModel) {
        guard let repo = listsRepository else { return }
        guard allLists.count > 1 else {
            errorMessage = "Die letzte Liste kann nicht gelöscht werden."
            return
        }
        logVoid(params: (action: "deleteList", listId: list.id, title: list.title))

        // Local: soft-delete and remove from UI
        try? listStore.delete(listId: list.id)
        allLists.removeAll { $0.id == list.id }
        listItemCounts.removeValue(forKey: list.id)
        UserLog.Data.listDeleted(name: list.title)

        // Switch active list if the deleted one was active
        if listId == list.id {
            let next = allLists.first(where: { $0.isDefault }) ?? allLists.first
            if let next {
                defaultList = next
                switchList(to: next.id)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await repo.deleteList(listId: list.id)
                await MainActor.run {
                    try? self.listStore.purge(listId: list.id)
                    logVoid(params: (action: "deleteList.success", listId: list.id))
                }
            } catch {
                // Rollback: re-insert list locally
                await MainActor.run {
                    _ = try? self.listStore.upsert(model: list)
                    self.allLists.append(list)
                    self.allLists.sort { $0.createdAt < $1.createdAt }
                    self.listItemCounts[list.id] = (try? self.itemStore.fetchItems(listId: list.id))?.count ?? 0
                    self.setError(error)
                    logVoid(params: (action: "deleteList.error", error: (error as NSError).localizedDescription))
                }
            }
        }
    }

    // MARK: - Set Default List

    /// Optimistically sets the given list as default, clearing the previous default.
    func setDefaultList(_ list: ListModel) {
        guard let repo = listsRepository else { return }
        let previousDefault = allLists.first(where: { $0.isDefault })
        logVoid(params: (action: "setDefaultList", listId: list.id, title: list.title))

        // Optimistic local update
        allLists = allLists.map { l in
            ListModel(id: l.id, ownerId: l.ownerId, title: l.title,
                      isDefault: l.id == list.id,
                      createdAt: l.createdAt, updatedAt: Date())
        }
        UserLog.Data.listSetDefault(name: list.title)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await repo.setDefaultList(listId: list.id, ownerId: list.ownerId)
                await MainActor.run {
                    logVoid(params: (action: "setDefaultList.success", listId: list.id))
                }
            } catch {
                // Rollback: restore previous default state
                await MainActor.run {
                    self.allLists = self.allLists.map { l in
                        ListModel(id: l.id, ownerId: l.ownerId, title: l.title,
                                  isDefault: l.id == previousDefault?.id,
                                  createdAt: l.createdAt, updatedAt: l.updatedAt)
                    }
                    self.setError(error)
                    logVoid(params: (action: "setDefaultList.error", error: (error as NSError).localizedDescription))
                }
            }
        }
    }

    // MARK: - Switch to List

    /// Switches the active list and updates defaultList for the UI.
    func switchToList(_ list: ListModel) {
        logVoid(params: (action: "switchToList", listId: list.id, title: list.title))
        defaultList = list
        switchList(to: list.id)
        UserLog.UI.viewChanged(to: "Liste: \(list.title)")
    }

    // MARK: - Private Helpers

    /// Updates allLists and SwiftData with a new title for the given list id.
    private func applyLocalListTitle(listId: UUID, title: String) {
        allLists = allLists.map { l in
            guard l.id == listId else { return l }
            return ListModel(id: l.id, ownerId: l.ownerId, title: title,
                             isDefault: l.isDefault, createdAt: l.createdAt, updatedAt: Date())
        }
        if let entity = try? listStore.fetchList(id: listId) {
            entity.title = title
            entity.setSyncStatus(.pendingUpdate)
            try? listStore.save()
        }
    }

    /// Re-reads all lists from SwiftData and refreshes allLists.
    private func refreshAllListsFromStore(ownerId: UUID) {
        guard let entities = try? listStore.fetchLists(ownerId: ownerId) else { return }
        allLists = entities.compactMap { $0.toListModel() }
    }
}
