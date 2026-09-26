/*
 ListViewModel+AllListsSync.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Alle Listen synchron halten, nicht nur die geöffnete (Watch-Plan §2, Phase 3): Im Vordergrund bleibt
   für JEDE Liste ein Realtime-Kanal offen. Änderungen landen über dieselbe HLC-Regel in SwiftData.

 🛠 Includes:
 - startAllListsSync / stopAllListsSync / updateAllListsSync: Menge der Kanäle an `allLists` anpassen.
 - syncListInBackground: Delta-Abgleich einer NICHT geöffneten Liste nach (Wieder-)Anmeldung ihres Kanals.
 - handleRemoteListChange: Zähler in „Meine Listen“ nach Änderungen von außen.

 🔰 Notes for Beginners:
 - Kanäle laufen nur im Vordergrund (wie bisher der Kanal der geöffneten Liste).
 - Supabase erlaubt 100 Kanäle je Verbindung (docs: Realtime Quotas). Dazu kommen die Kanäle für
   Mitgliedschaften; bei mehr als `maxSyncedLists` Listen bleiben die übrigen beim Delta-Abgleich.
 - Die Apple Watch bekommt diese Änderungen in Phase 4 über den remoteChangeHandler weitergeleitet.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    /// Höchstzahl gleichzeitig abonnierter Listen (Supabase: 100 Kanäle je Verbindung, Rest als Reserve).
    static let maxSyncedLists = 90

    /// Vordergrund: Kanäle aller Listen öffnen (aufgerufen aus startObserving).
    internal func startAllListsSync() {
        repository.setRemoteChangeHandler { [weak self] changedList, _ in
            self?.handleRemoteListChange(changedList)
        }
        isAllListsSyncActive = true
        updateAllListsSync()
    }

    /// Hintergrund oder Abmelden: nur noch Kanäle mit Beobachtern (keiner, sobald die Liste geschlossen ist).
    internal func stopAllListsSync() {
        isAllListsSyncActive = false
        repository.keepListsInSync([])
    }

    /// Menge der synchronen Listen an `allLists` anpassen (neue Liste, Liste gelöscht, Zugriff entzogen).
    internal func updateAllListsSync() {
        guard isAllListsSyncActive else { return }
        repository.keepListsInSync(syncedListIds())
    }

    /// Geöffnete Liste zuerst, dann die übrigen in der Reihenfolge von `allLists`; höchstens `maxSyncedLists`.
    internal func syncedListIds() -> Set<UUID> {
        let placeholder = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        let ordered = [listId] + allLists.map(\.id)
        var result: Set<UUID> = []
        for id in ordered where id != placeholder && result.count < Self.maxSyncedLists {
            result.insert(id)
        }
        return result
    }

    /// Kanal einer Liste wieder angemeldet: Verpasstes nachholen. Geöffnete Liste → normaler Delta-Abgleich
    /// (mit Anzeige); andere Liste → Abgleich nur in SwiftData.
    internal func handleChannelResubscribed(_ reconnectedList: UUID) {
        if reconnectedList == listId {
            Task { await self.runIncrementalSync() }
        } else {
            Task { await self.syncListInBackground(reconnectedList) }
        }
    }

    /// Delta-Abgleich einer nicht geöffneten Liste; gleiche Regeln wie runIncrementalSync (HLC, Zeitmarke
    /// erst nach dem Speichern, 5 s Überlappung).
    internal func syncListInBackground(_ syncListId: UUID) async {
        guard isAllListsSyncActive, syncListId != listId else { return }
        let lastSync = loadLastSyncTimestamp(for: syncListId)
        do {
            let delta = try await repository.fetchItemsSince(listId: syncListId, since: Self.deltaStart(after: lastSync))
            // Inzwischen abgemeldet oder Zugriff verloren → nichts mehr übernehmen.
            guard isAllListsSyncActive, allLists.contains(where: { $0.id == syncListId }) else { return }
            let changed = try applyDelta(delta, listId: syncListId, lastSync: lastSync)
            if syncListId == listId { refreshItemsFromStore() }        // inzwischen geöffnet
            updateListItemCount(syncListId)
            logVoid(params: (action: "syncListInBackground", listId: syncListId, rows: delta.count, changed: changed.count))
        } catch {
            logVoid(params: (action: "syncListInBackground.error", listId: syncListId,
                             error: (error as NSError).localizedDescription))
        }
    }

    /// Realtime hat Änderungen einer Liste übernommen (auch der geöffneten): Zähler in „Meine Listen“.
    internal func handleRemoteListChange(_ changedList: UUID) {
        updateListItemCount(changedList)
    }

    /// Zähler einer Liste aus SwiftData neu lesen (nur für bekannte Listen).
    internal func updateListItemCount(_ list: UUID) {
        guard allLists.contains(where: { $0.id == list }) else { return }
        listItemCounts[list] = (try? itemStore.fetchItems(listId: list))?.count ?? 0
    }
}
