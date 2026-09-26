/*
 ListViewModel+RealtimeSync.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension managing real-time observation, incremental sync, and app-lifecycle transitions.

 🛠 Includes:
 - startObserving: loads local snapshot → starts Realtime → runs IncrementalSync.
 - runIncrementalSync: delta-fetch since lastSyncTimestamp; upserts creates/updates; applies tombstones.
 - handleAppDidBecomeActive / handleAppDidEnterBackground: lifecycle-driven sync control.
 - resumeRealtimeSync: reconnection logic when connectivity returns.

 🔰 Notes for Beginners:
 - IncrementalSync replaces full fetchAndYield() after each Realtime event (FAM-41).
 - Realtime events are now processed granularly by RealtimeEventProcessor (no full refetch).
 - SyncOrchestrator buffers Realtime handlers that arrive during an active page load.

 📝 Last Change:
 - Alle Listen synchron (ListViewModel+AllListsSync): Wiederverbindung jeder Liste holt nach, Kanäle
   aller Listen starten mit der Beobachtung und pausieren im Hintergrund. Übernahme des Deltas in
   applyDelta ausgelagert (Watch-Plan Phase 3, 26.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

// MARK: - Real-time Observation

extension ListViewModel {

    /// Starts (or restarts) the background observation of items for the current listId.
    ///
    /// Sequence (per FAM-24 canonical App-Start protocol):
    ///   1. loadLocalSnapshot()    — immediate, no network
    ///   2. Start Realtime subscription (via observeItems)
    ///   3. runIncrementalSync()   — async, fetches delta since lastSyncTimestamp
    ///   4. Pagination waits for User-Scroll
    internal func startObserving() {
        observeTask?.cancel()
        loadLocalSnapshot()
        hasObservedActiveList = true
        // Nach einem Realtime-Abbruch Verpasstes nachholen (Audit M4) – für jede Liste, nicht nur die geöffnete.
        repository.setReconnectHandler { [weak self] reconnectedList in
            self?.handleChannelResubscribed(reconnectedList)
        }
        startAllListsSync()
        // Restore persisted cursor so pagination continues from where it left off after app restart.
        if currentCursor == nil {
            currentCursor = PaginationCursor.load(listId: listId)
        }

        // Step 2: Subscribe to Realtime events via the AsyncStream.
        // The stream now yields only when a Realtime event is processed (no initial fetchAndYield).
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in repository.observeItems(listId: listId) {
                await MainActor.run {
                    // Suppress stream yields during bulk mutations (import / delete-all)
                    // so the UI only sees stable before/after states.
                    guard !self.isBulkMutationActive else { return }
                    let sorted = ListViewModel.currentSortOrder.apply(to: snapshot)

                    // Detect items freshly applied from a remote Realtime event.
                    // Compare HLC timestamps between the incoming snapshot and the current UI state.
                    // Items whose HLC changed or that are entirely new were written by a remote device.
                    // Items with in-flight local animations are excluded (they are local mutations).
                    let currentItems = self.items
                    let oldIDs = Set(currentItems.map { $0.id })
                    // uniquingKeysWith: doppelte IDs dürfen nie zum Absturz führen.
                    let oldTimestamps = Dictionary(
                        currentItems.compactMap { item -> (String, Int64)? in
                            guard let ts = item.hlcTimestamp else { return nil }
                            return (item.id, ts)
                        },
                        uniquingKeysWith: { _, latest in latest }
                    )
                    let remoteChangedIDs: Set<String> = Set(sorted.compactMap { item -> String? in
                        guard !self.pendingAnimatedItemIDs.contains(item.id) else { return nil }
                        guard !self.pendingBulkDeleteIDs.contains(item.id) else { return nil }
                        if !oldIDs.contains(item.id) { return item.id } // New item from remote
                        let oldTs = oldTimestamps[item.id]
                        let newTs = item.hlcTimestamp
                        if oldTs != newTs { return item.id } // HLC changed → remote update
                        return nil
                    })
                    if !remoteChangedIDs.isEmpty {
                        self.markRecentlySynced(ids: remoteChangedIDs)
                    }

                    // applyItems filters pendingBulkDeleteIDs and guards against redundant UI updates.
                    self.applyItems(sorted)
                    self.prefetchImages()                    // neues Foto eines anderen Geräts sofort laden
                }
            }
        }

        // Step 3: Incremental sync — runs concurrently with the Realtime subscription.
        incrementalSyncTask?.cancel()
        incrementalSyncTask = Task { [weak self] in
            await self?.runIncrementalSync()
            guard !Task.isCancelled, let self else { return }
            self.prefetchImages()
            await self.syncEngine?.migrateLegacyImages(listId: self.listId)
            await self.backfillImagesFromCatalog()   // Fotos aus dem Artikelstamm nachtragen
        }
    }

    // MARK: - Incremental Sync (FAM-41)

    /// Fetches all remote changes since `lastSyncTimestamp` and applies them to SwiftData.
    ///
    /// - Creates/Updates → upsert into SwiftData.
    /// - Tombstones (tombstone=true) → applyRemoteTombstoneModel() → purge from SwiftData.
    /// - On success: lastSyncTimestamp = max(updated_at) of returned items.
    /// - On failure: lastSyncTimestamp NOT updated; cached data remains visible.
    /// - Parameter suppressHighlight: Pass `true` from pullToRefresh() to avoid highlighting
    ///   all delta items during a user-triggered full refresh (only genuine background
    ///   or foreground syncs should trigger the remote-highlight animation).
    @MainActor
    func runIncrementalSync(suppressHighlight: Bool = false) async {
        // Liste zu Beginn festhalten: Wechselt der Nutzer währenddessen die Liste, darf die Zeitmarke
        // nicht unter der neuen Liste landen (Audit M2).
        let syncListId = listId
        let lastSync = loadLastSyncTimestamp(for: syncListId)
        let since = Self.deltaStart(after: lastSync)
        logVoid(params: (action: "runIncrementalSync.start", listId: syncListId, since: since))
        do {
            let deltaItems = try await repository.fetchItemsSince(listId: syncListId, since: since)
            guard !Task.isCancelled, syncListId == listId else { return }
            let changes = try applyDelta(deltaItems, listId: syncListId, lastSync: lastSync)
            if !suppressHighlight { markRecentlySynced(ids: changes.visible) }
            if !changes.all.isEmpty { remoteChangeForwarder?(syncListId, changes.all) }
            updateListItemCount(syncListId)
            refreshItemsFromStore()
            logVoid(params: (action: "runIncrementalSync.success", listId: syncListId, itemCount: deltaItems.count))
            // Nach langer Pause: endgültig gelöschte Artikel entfernen (Audit 2, Befund S3).
            if lastSync != .distantPast { await reconcileIfStale(listId: syncListId) }
        } catch {
            // Zeitmarke bleibt; der lokale Stand wird trotzdem angezeigt.
            refreshItemsFromStore()
            logVoid(params: (action: "runIncrementalSync.error", listId: syncListId,
                             error: (error as NSError).localizedDescription))
        }
    }

    /// Beginn des Delta-Fensters. 5 s Überlappung: Zeilen, deren Transaktion kurz vor der Zeitmarke begann,
    /// aber erst danach sichtbar wurde, sonst nie nachgeladen (Audit 2, Befund S7). Doppelte Zeilen erkennt
    /// die HLC-Regel.
    nonisolated static func deltaStart(after lastSync: Date) -> Date {
        lastSync == .distantPast ? lastSync : lastSync.addingTimeInterval(-5)
    }

    /// Übernimmt Delta-Zeilen einer Liste per HLC (auch Löschmarkierungen: neuere HLC gewinnt), speichert und
    /// rückt die Zeitmarke erst DANACH vor – über alle Zeilen.
    /// - Returns: `visible` = geänderte, nicht gelöschte Artikel (Hervorhebung); `all` = alle geänderten
    ///   (auch Löschungen, zum Weiterleiten an die Uhr).
    internal func applyDelta(_ deltaItems: [ItemModel], listId syncListId: UUID,
                             lastSync: Date) throws -> (visible: Set<String>, all: Set<String>) {
        var visible: Set<String> = [], all: Set<String> = []
        for item in deltaItems {
            guard try itemStore.mergeRemote(item, legacyImageKnown: false) != .ignored else { continue }
            all.insert(item.id)
            if item.tombstone != true { visible.insert(item.id) }
        }
        try itemStore.save()
        if let newest = deltaItems.compactMap(\.updatedAt).max(), newest > lastSync {
            saveLastSyncTimestamp(newest, for: syncListId)
        }
        return (visible, all)
    }

    // MARK: - App Lifecycle

    /// Signals that the app moved into the foreground so realtime sync should resume if it was suspended.
    /// Also triggers IncrementalSync to pick up changes that arrived while backgrounded.
    func handleAppDidBecomeActive() {
        syncEngine?.resume()
        resumeRealtimeSync(trigger: .appForeground)
        // Note: startObserving() called by resumeRealtimeSync() already calls runIncrementalSync().
    }

    /// Signals that the app transitioned to background so realtime observation can pause to save resources.
    func handleAppDidEnterBackground() {
        // Laufendes Rückgängig-Fenster festschreiben: Beendet das System die App im Hintergrund, wäre die
        // Löschung sonst verloren und die Artikel beim nächsten Start wieder da (Audit 2, Befund S15).
        _ = commitPendingDeletion()
        syncEngine?.pause()
        stopAllListsSync()                                  // Kanäle aller Listen nur im Vordergrund
        guard observeTask != nil else { return }
        logVoid(params: (
            action: "pauseRealtimeSync",
            listId: listId,
            reason: "background"
        ))
        UserLog.Sync.realtimePaused(listName: defaultList?.title)
        observeTask?.cancel()
        observeTask = nil
    }

    /// Restarts realtime observation if a prior observation existed and logs the trigger for debugging.
    internal func resumeRealtimeSync(trigger: ResumeTrigger) {
        guard hasObservedActiveList else { return }
        logVoid(params: (
            action: "resumeRealtimeSync",
            listId: listId,
            trigger: trigger.rawValue
        ))
        UserLog.Sync.realtimeResumed(listName: defaultList?.title)
        startObserving()
    }

    /// Kein Zugriff mehr: Artikel, Fotos, Warteschlange und Zwischenstände dieser Liste vom Gerät löschen.
    /// Vorher blieben sie nach dem Entfernen aus einer geteilten Liste gespeichert (Audit 25.09.2026).
    internal func forgetLocalData(of removedListId: UUID) {
        syncEngine?.forgetList(removedListId)
        let purged = (try? itemStore.purgeAll(listId: removedListId)) ?? 0
        try? listStore.purge(listId: removedListId)
        try? listStore.save()
        PaginationCursor.clear(listId: removedListId)
        UserDefaults.standard.removeObject(forKey: "fam24_last_sync_ts_\(removedListId.uuidString)")
        listItemCounts[removedListId] = nil
        logVoid(params: (action: "forgetLocalData", listId: removedListId, purgedItems: purged))
    }

    // MARK: - Membership Observation (FAM-21 Bug Fix)

    /// Startet eine Realtime-Beobachtung auf list_members DELETE-Events für den angegebenen User.
    /// Wird beim Login gestartet und bei Sign-Out via clearForSignOut() gestoppt.
    func startObservingMemberships(userId: UUID) {
        guard let repo = listsRepository else { return }
        membershipTask?.cancel()
        membershipTask = Task { [weak self] in
            guard let self else { return }
            for await removedListId in repo.observeMemberRemovals(userId: userId) {
                await MainActor.run {
                    self.handleMembershipRemoval(listId: removedListId)
                }
            }
        }
        logVoid(params: (action: "startObservingMemberships", userId: userId))
    }

    /// Verarbeitet den Verlust einer Listenmitgliedschaft.
    /// Entfernt die Liste aus allLists; wechselt auf Standardliste falls aktiv.
    internal func handleMembershipRemoval(listId removedListId: UUID) {
        logVoid(params: (action: "handleMembershipRemoval", listId: removedListId))
        allLists.removeAll { $0.id == removedListId }
        forgetLocalData(of: removedListId)

        guard listId == removedListId else { return } // Nicht aktive Liste → kein Wechsel nötig

        UserLog.Data.accessRevoked()

        let fallback = allLists.first(where: { $0.isDefault }) ?? allLists.first
        if let fallback {
            switchToList(fallback)  // Teardown items-Channel + Switch in einem Aufruf
        } else {
            // Edge Case: keine verbleibende Liste
            observeTask?.cancel()
            observeTask = nil
            items = []
            defaultList = nil
        }
    }
}
