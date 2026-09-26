/*
 WatchSyncCoordinator+Pull.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abfrage der Uhr (alle 10 s bei sichtbarer App): Listen, Favorit, Kategorien und das Delta ALLER Listen
   in einem Aufruf (fetchItemsSince(listIds:since:), Phase 3). Übernahme nur per HLC (mergeRemote).

 🔰 Notes for Beginners:
 - Listen, die der Server nicht mehr liefert (gelöscht, Zugriff entzogen), verschwinden samt Artikeln und
   wartenden Aufträgen von der Uhr.
 - Nach langer Pause (über 25 Tage) holt die Uhr alle Listen komplett neu: Der Server löscht
   Löschmarkierungen nach 30 Tagen endgültig; ohne Neuabgleich blieben gelöschte Artikel stehen.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

extension WatchSyncCoordinator {
    /// Nach dieser Pause gleicht die Uhr alle Listen vollständig ab (Server: Löschmarkierungen 30 Tage).
    static let fullResyncAge: TimeInterval = 25 * 24 * 3600
    /// Artikelstamm („Oft gekauft“) höchstens so oft neu laden.
    static let catalogRefreshInterval: TimeInterval = 300

    /// Einmal abfragen. Mehrere gleichzeitige Aufrufe laufen nicht doppelt.
    func pull() async {
        guard let remote, let account = userId(), !isPulling else { return }
        isPulling = true
        defer { isPulling = false }
        do {
            let lists = try await remote.fetchLists(userId: account)
            guard userId() == account else { return }                // währenddessen abgemeldet
            var changed = try applyLists(lists)
            changed = await pullSettings(remote, account: account) || changed
            changed = try await pullItems(listIds: Set(lists.map(\.id))) || changed
            await catalog.flush()
            await refreshCatalogIfDue()
            if changed { bump() }
        } catch {
            logVoid(params: (action: "watchSync.pull.error", error: error.localizedDescription))
        }
    }

    /// Listen speichern; nicht mehr gelieferte Listen samt Artikeln entfernen. true = etwas geändert.
    func applyLists(_ lists: [ListModel]) throws -> Bool {
        let before = try listStore.fetchLists().compactMap { $0.toListModel() }
        let serverIds = Set(lists.map(\.id))
        for gone in before where !serverIds.contains(gone.id) {
            engine.forgetList(gone.id)
            _ = try itemStore.purgeAll(listId: gone.id)
            try listStore.purge(listId: gone.id)
        }
        for list in lists { try listStore.upsert(model: list) }
        try listStore.save()
        let signature: ([ListModel]) -> Set<String> = { Set($0.map { "\($0.id)|\($0.title)|\($0.isDefault)" }) }
        return signature(before) != signature(lists)
    }

    /// Favorit und Kategorien; Fehler lassen den letzten Stand stehen. true = etwas geändert.
    private func pullSettings(_ remote: WatchRemoteSource, account: UUID) async -> Bool {
        var changed = false
        if let favorite = try? await remote.fetchFavoriteListId(), favorite != favoriteListId {
            favoriteListId = favorite
            defaults.set(favorite.uuidString, forKey: Self.favoriteKey)
            changed = true
        }
        if let fetched = try? await remote.fetchCategories(userId: account), !fetched.isEmpty, fetched != categories {
            categories = fetched
            defaults.set(try? JSONEncoder().encode(fetched), forKey: Self.categoriesKey)
            changed = true
        }
        return changed
    }

    /// Delta aller Listen: neue Listen komplett, bekannte seit der Zeitmarke. true = etwas geändert.
    func pullItems(listIds: Set<UUID>) async throws -> Bool {
        let marks = self.marks
        let fullResync = marks.since != .distantPast && Date().timeIntervalSince(marks.since) > Self.fullResyncAge
        let known = fullResync ? [] : marks.knownLists
        let fresh = listIds.subtracting(known), current = listIds.intersection(known)
        var rows: [ItemModel] = []
        if !fresh.isEmpty { rows += try await itemsRepository.fetchItemsSince(listIds: fresh.sorted(by: uuidOrder), since: .distantPast) }
        if !current.isEmpty { rows += try await itemsRepository.fetchItemsSince(listIds: current.sorted(by: uuidOrder), since: marks.windowStart) }
        guard userId() != nil else { return false }
        var changed = false
        for row in rows {
            if try itemStore.mergeRemote(row, legacyImageKnown: false) != .ignored { changed = true }
        }
        if fullResync { changed = try removeVanished(from: fresh, serverIds: Set(rows.map(\.id))) || changed }
        try itemStore.save()
        if let newest = rows.compactMap(\.updatedAt).max(), newest > marks.since { marks.since = newest }
        marks.knownLists = listIds
        return changed
    }

    /// Neuabgleich: Artikel, die der Server nicht mehr kennt und die keine wartende eigene Änderung haben.
    private func removeVanished(from lists: Set<UUID>, serverIds: Set<String>) throws -> Bool {
        var removed = 0
        for list in lists {
            for entity in try itemStore.fetchItems(listId: list, includeDeleted: true)
            where !serverIds.contains(entity.id.uuidString) && !engine.operationQueue.hasPendingOperation(itemId: entity.id.uuidString) {
                try itemStore.purge(id: entity.id)
                removed += 1
            }
        }
        logVoid(params: (action: "watchSync.fullResync", lists: lists.count, removed: removed))
        return removed > 0
    }

    /// Artikelstamm für „Oft gekauft“ auffrischen (höchstens alle 5 Minuten; offline bleibt die Kopie).
    func refreshCatalogIfDue(force: Bool = false) async {
        if !force, let last = lastCatalogRefresh, Date().timeIntervalSince(last) < Self.catalogRefreshInterval { return }
        lastCatalogRefresh = Date()
        _ = try? await catalog.fetchAll()
        bump()
    }

    private func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool { lhs.uuidString < rhs.uuidString }
}
