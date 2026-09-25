/*
 OfflineListsRepository.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listen offline zuerst: Anlegen, Umbenennen, Löschen, Standard setzen und Verlassen wirken sofort
   lokal und werden in einer Warteschlange gespeichert. Gesendet wird, sobald Netz da ist.
 - Lesen liefert ohne Netz die lokale Kopie (eigene und geteilte Listen).

 🔰 Notes for Beginners:
 - Vorher gingen diese Aktionen nur online: offline sprang der Titel zurück, neue Listen entstanden
   nicht, und die Listenübersicht blieb leer (Audit M3).
 - Neue Listen bekommen ihre ID auf dem Gerät. `isListReady` meldet der SyncEngine, ob die Liste schon
   auf dem Server existiert – vorher werden ihre Artikel nicht gesendet (sonst lehnt der Server sie ab).
 - Einladungen, Mitglieder und die „entfernt“-Meldung brauchen den Server und werden durchgereicht.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation
import Supabase

@MainActor
final class OfflineListsRepository: ListsRepository {
    private let remote: ListsRepository
    let store: ListLocalStore
    private var flushTask: Task<Void, Never>?
    private var reconnectSubscription: AnyCancellable?

    /// Listen, die beim Abgleich mit dem Server fehlen (gelöscht oder entfernt) → lokale Daten löschen.
    var onListsVanished: (([UUID]) -> Void)?
    /// Nach erfolgreichem Senden (z. B. neue Liste angelegt) → wartende Artikel senden.
    var onFlushed: (() -> Void)?

    init(remote: ListsRepository, store: ListLocalStore? = nil, reconnect: AnyPublisher<Bool, Never>? = nil) {
        self.remote = remote
        self.store = store ?? ListLocalStore()
        reconnectSubscription = reconnect?
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in Task { await self?.flush() } }
    }

    /// true, sobald die Liste auf dem Server existiert (kein wartender Auftrag „anlegen“).
    func isListReady(_ listId: UUID) -> Bool {
        !store.outbox.contains { pending in
            if case .create(let list) = pending.operation { return list.id == listId }
            return false
        }
    }

    // MARK: - Lesen

    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] {
        await flush()
        do {
            let remoteLists = try await remote.fetchAllLists(for: ownerId)
            let previous = Set((store.cache ?? []).map(\.id))
            store.setCache(remoteLists)
            let pendingCreates = Set(store.outbox.compactMap { pending -> UUID? in
                if case .create(let list) = pending.operation { return list.id }
                return nil
            })
            let vanished = previous.subtracting(remoteLists.map(\.id)).subtracting(pendingCreates)
            if !vanished.isEmpty { onListsVanished?(Array(vanished)) }
        } catch {
            guard store.lists != nil, SyncErrorClassifier.classify(error) != .permanent else { throw error }
            logVoid(params: (action: "lists.fetchAll.offline", pending: store.outbox.count))
        }
        return store.lists ?? []
    }

    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel {
        if let cached = store.lists?.first(where: { $0.ownerId == ownerId && $0.isDefault }) {
            return cached
        }
        do {
            let list = try await remote.fetchDefaultList(for: ownerId)
            store.setCache(((store.cache ?? []).filter { $0.id != list.id }) + [list])
            return list
        } catch where SyncErrorClassifier.classify(error) != .permanent {
            // Allererster Start ohne Netz: Standardliste lokal anlegen, später senden.
            let local = ListModel(id: UUID(), ownerId: ownerId, title: "My List", isDefault: true,
                                  createdAt: Date(), updatedAt: Date())
            store.append(.create(local))
            logVoid(params: (action: "lists.defaultCreatedOffline", listId: local.id))
            return local
        }
    }

    func ensureDefaultListExists(for owner: UUID) async throws -> List {
        let model = try await fetchDefaultList(for: owner)
        return List(id: model.id, owner_id: model.ownerId, title: model.title, is_default: model.isDefault,
                    created_at: model.createdAt, updated_at: model.updatedAt)
    }

    func observeLists(for owner: UUID) -> AsyncStream<[List]> {
        remote.observeLists(for: owner)
    }

    // MARK: - Schreiben (lokal sofort, Senden später)

    func createList(for owner: UUID, title: String) async throws -> List {
        try await createList(id: UUID(), for: owner, title: title)
    }

    func createList(id: UUID, for owner: UUID, title: String) async throws -> List {
        let now = Date()
        let model = ListModel(id: id, ownerId: owner, title: title, isDefault: false, createdAt: now, updatedAt: now)
        enqueue(.create(model))
        return List(id: id, owner_id: owner, title: title, is_default: false, created_at: now, updated_at: now)
    }

    func renameList(listId: UUID, title: String) async throws -> ListModel {
        guard store.lists?.contains(where: { $0.id == listId }) == true else { throw URLError(.fileDoesNotExist) }
        enqueue(.rename(id: listId, title: title))
        guard let updated = store.lists?.first(where: { $0.id == listId }) else { throw URLError(.fileDoesNotExist) }
        return updated
    }

    func deleteList(listId: UUID) async throws {
        enqueue(.delete(id: listId))
    }

    func setDefaultList(listId: UUID, ownerId: UUID) async throws {
        enqueue(.setDefault(id: listId, ownerId: ownerId))
    }

    func leaveList(listId: UUID, profileId: UUID) async throws {
        enqueue(.leave(id: listId, profileId: profileId))
    }

    private func enqueue(_ operation: ListOperation) {
        store.append(operation)
        Task { await flush() }
    }

    // MARK: - Durchreichen (brauchen den Server)

    func removeMember(listId: UUID, profileId: UUID) async throws {
        try await remote.removeMember(listId: listId, profileId: profileId)
    }

    func fetchMembers(listId: UUID) async throws -> [ListMember] { try await remote.fetchMembers(listId: listId) }
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> { remote.observeMemberRemovals(userId: userId) }
    func createInvite(listId: UUID) async throws -> String { try await remote.createInvite(listId: listId) }
    func invitePreview(token: String) async throws -> InvitePreviewRow? { try await remote.invitePreview(token: token) }
    func acceptInvite(token: String) async throws -> UUID { try await remote.acceptInvite(token: token) }

    // MARK: - Senden

    /// Sendet die Warteschlange der Reihe nach. Läuft schon ein Durchgang, wird auf ihn gewartet.
    func flush() async {
        while let running = flushTask { await running.value }
        guard !store.outbox.isEmpty else { return }
        let task = Task { await self.drain(); self.flushTask = nil }
        flushTask = task
        await task.value
    }

    private func drain() async {
        var sentAny = false
        while let pending = store.outbox.first {
            do {
                try await send(pending.operation)
                store.removeFirst()
                sentAny = true
            } catch {
                let kind = SyncErrorClassifier.classify(error)
                if kind != .permanent {
                    logVoid(params: (action: "lists.flush.deferred", kind: "\(kind)", pending: store.outbox.count))
                    break
                }
                // Dauerhaft (z. B. Liste inzwischen gelöscht, schon angelegt): Wiederholen hilft nicht.
                logVoid(params: (action: "lists.flush.dropped", listId: pending.operation.listId,
                                 error: (error as NSError).localizedDescription))
                store.removeFirst()
            }
        }
        if sentAny { onFlushed?() }
    }

    private func send(_ operation: ListOperation) async throws {
        switch operation {
        case .create(let list):
            if list.isDefault {
                let server = try await remote.ensureDefaultList(id: list.id, for: list.ownerId)
                if server.id != list.id {
                    // Ein anderes Gerät hatte schon eine Standardliste: diese hier als normale Liste anlegen,
                    // damit offline hinzugefügte Artikel nicht verloren gehen.
                    _ = try await createIgnoringDuplicate(list)
                }
            } else {
                _ = try await createIgnoringDuplicate(list)
            }
        case .rename(let id, let title):
            _ = try await remote.renameList(listId: id, title: title)
        case .delete(let id):
            try await remote.deleteList(listId: id)
        case .setDefault(let id, let ownerId):
            try await remote.setDefaultList(listId: id, ownerId: ownerId)
        case .leave(let id, let profileId):
            try await remote.removeMember(listId: id, profileId: profileId)
        }
    }

    /// Anlegen ist wiederholbar: Kam die Antwort beim letzten Mal nicht an, meldet der Server „schon da“.
    private func createIgnoringDuplicate(_ list: ListModel) async throws {
        do {
            _ = try await remote.createList(id: list.id, for: list.ownerId, title: list.title)
        } catch let error as PostgrestError where error.code == "23505" {
            logVoid(params: (action: "lists.create.alreadyExists", listId: list.id))
        }
    }

    /// Abmelden: lokale Kopie und Warteschlange verwerfen.
    func clearLocalData() {
        store.clear()
    }
}
