/*
 ListViewModel+Reconcile.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abgleich nach langer Pause: Der Server löscht Löschmarkierungen 30 Tage nach der Löschung endgültig
   (Cron tombstone-gc). Ein Gerät, das eine Liste länger nicht geöffnet hat, erfährt davon weder per
   Realtime noch per Nachladen und zeigte gelöschte Artikel als „Geister“ – änderte man einen, erschien
   er bei allen wieder (Audit 2, Befund S3).
 - Lösung: War der letzte Abgleich einer Liste länger als 25 Tage her, holt die App alle Artikel-IDs der
   Liste und entfernt synchrone lokale Artikel, die es auf dem Server nicht mehr gibt.

 🔰 Notes for Beginners:
 - Nur Artikel mit Status `.synced` werden entfernt. Ungesendete eigene Änderungen (pending…, failed)
   bleiben und werden normal gesendet.
 - Die Zeitmarke ist Gerätezeit; sie entscheidet nur, WANN abgeglichen wird, nicht welche Daten gewinnen.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// Abgleich spätestens alle 25 Tage – sicher unter der 30-Tage-Frist des Servers.
    static let reconcileInterval: TimeInterval = 25 * 24 * 60 * 60

    /// Gleicht die Liste ab, wenn der letzte Abgleich zu lange her ist. Fehler sind unkritisch (nächstes Mal).
    func reconcileIfStale(listId syncListId: UUID, now: Date = Date()) async {
        let key = Self.reconcileKey(syncListId)
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           now.timeIntervalSince(last) < Self.reconcileInterval { return }
        do {
            guard let serverIds = try await repository.fetchItemIds(listId: syncListId) else { return }
            guard !Task.isCancelled, syncListId == listId else { return }
            let removed = try removeVanishedItems(listId: syncListId, serverIds: serverIds)
            UserDefaults.standard.set(now, forKey: key)
            if removed > 0 { refreshItemsFromStore() }
            logVoid(params: (action: "reconcile.done", listId: syncListId, removed: removed))
        } catch {
            logVoid(params: (action: "reconcile.error", listId: syncListId, error: (error as NSError).localizedDescription))
        }
    }

    /// Entfernt synchrone lokale Artikel, die der Server nicht mehr kennt. Rückgabe: Anzahl.
    func removeVanishedItems(listId: UUID, serverIds: Set<String>) throws -> Int {
        let known = Set(serverIds.map { $0.lowercased() })
        let vanished = try itemStore.fetchItems(listId: listId, includeDeleted: true)
            .filter { $0.syncStatus == .synced && !known.contains($0.id.uuidString.lowercased()) }
        for entity in vanished { try itemStore.purge(id: entity.id) }
        if !vanished.isEmpty { try itemStore.save() }
        return vanished.count
    }

    static func reconcileKey(_ listId: UUID) -> String { "fam24_last_reconcile_\(listId.uuidString)" }
}
