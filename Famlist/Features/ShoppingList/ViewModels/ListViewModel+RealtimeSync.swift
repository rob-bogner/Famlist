/*
 ListViewModel+RealtimeSync.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 17.03.2026

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
 - FAM-41: IncrementalSync integration; removed fetchAndYield / persistRemoteSnapshot from observe loop.
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
                    let oldTimestamps = Dictionary(
                        uniqueKeysWithValues: currentItems.compactMap { item -> (String, Int64)? in
                            guard let ts = item.hlcTimestamp else { return nil }
                            return (item.id, ts)
                        }
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

                    // P5: Safety-net reconciliation for missed Realtime DELETE events.
                    // When the incoming snapshot has fewer items than the current UI state,
                    // a remote deletion may not have been reflected by a Realtime event
                    // (e.g. event dropped during a brief network interruption).
                    // Schedule a debounced IncrementalSync so the state converges correctly.
                    // Only triggers on item-count decrease — not on adds or updates.
                    let previousCount = self.items.count
                    let incomingCount = sorted.count
                    if incomingCount < previousCount {
                        self.scheduleReconciliationSync()
                    }

                    // applyItems filters pendingBulkDeleteIDs and guards against redundant UI updates.
                    self.applyItems(sorted)
                }
            }
        }

        // Step 3: Incremental sync — runs concurrently with the Realtime subscription.
        Task { [weak self] in
            await self?.runIncrementalSync()
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
        let since = loadLastSyncTimestamp()
        logVoid(params: (action: "runIncrementalSync.start", listId: listId, since: since))

        do {
            let deltaItems = try await repository.fetchItemsSince(listId: listId, since: since)

            var maxUpdatedAt: Date? = nil
            var highlightIDs: Set<String> = []
            for item in deltaItems {
                if item.tombstone == true {
                    applyRemoteTombstoneModel(item)
                } else {
                    // Skip upsert for items that have a pending local mutation (.pendingUpdate /
                    // .pendingCreate).  The remote delta may carry stale field values (e.g. units=1
                    // while the user just incremented to units=2) and must not overwrite the
                    // in-flight local change before the SyncEngine has a chance to confirm it.
                    let itemUUID = UUID(uuidString: item.id)
                    let hasPendingLocalChange: Bool = {
                        guard let uuid = itemUUID,
                              let entity = try? itemStore.fetchItem(id: uuid) else { return false }
                        return entity.hasPendingLocalChange
                    }()
                    if !hasPendingLocalChange {
                        _ = try? itemStore.upsert(model: item)
                        if !suppressHighlight {
                            highlightIDs.insert(item.id)
                        }
                    }
                }
                // P2: Advance the high-water mark for ALL delta items, including tombstones.
                // Without this, a delta window that contains only tombstones (remote deletes)
                // leaves lastSyncTimestamp unchanged, causing the same tombstones to be
                // re-fetched on every subsequent sync until a non-tombstone arrives.
                if let updatedAt = item.updatedAt {
                    maxUpdatedAt = maxUpdatedAt.map { max($0, updatedAt) } ?? updatedAt
                }
            }
            try? itemStore.save()

            if !suppressHighlight {
                markRecentlySynced(ids: highlightIDs)
            }

            // Advance high-water mark whenever any delta item (create, update, or tombstone)
            // was returned — not only when non-tombstone items were present.
            if let newTs = maxUpdatedAt {
                saveLastSyncTimestamp(newTs)
            }

            refreshItemsFromStore()
            logVoid(params: (
                action: "runIncrementalSync.success",
                listId: listId,
                itemCount: deltaItems.count,
                newTimestamp: maxUpdatedAt as Any
            ))
        } catch {
            // On failure: do not advance lastSyncTimestamp.
            // Still refresh from the local SwiftData cache so that any items written
            // by storeLocally() (e.g. a just-added item) become visible even when
            // the network is unavailable or fetchItemsSince() throws.
            refreshItemsFromStore()
            logVoid(params: (
                action: "runIncrementalSync.error",
                listId: listId,
                error: (error as NSError).localizedDescription
            ))
        }
    }

    // MARK: - App Lifecycle

    /// Signals that the app moved into the foreground so realtime sync should resume if it was suspended.
    /// Also triggers IncrementalSync to pick up changes that arrived while backgrounded.
    func handleAppDidBecomeActive() {
        resumeRealtimeSync(trigger: .appForeground)
        // Note: startObserving() called by resumeRealtimeSync() already calls runIncrementalSync().
    }

    /// Signals that the app transitioned to background so realtime observation can pause to save resources.
    func handleAppDidEnterBackground() {
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

        // P9: Restart the membership-channel so eviction events are not silently missed
        // after a WebSocket disconnect (e.g. network switch, backgrounding).
        if let userId = membershipUserId {
            startObservingMemberships(userId: userId)
        }
    }

    // MARK: - Reconciliation Safety Net (P5)

    /// Schedules a debounced IncrementalSync as a safety net for missed Realtime DELETE events.
    ///
    /// Called by the stream handler when the incoming snapshot count drops below the current
    /// UI item count — indicating that a remote deletion may not have been reflected by an
    /// individual Realtime event (e.g. dropped during a brief network interruption or during
    /// a bulk-delete from another device).
    ///
    /// Debounce behaviour:
    /// - Any in-flight reconciliation task is cancelled and replaced.
    /// - After a 500 ms quiet period, IncrementalSync runs once.
    /// - Rapid successive calls coalesce into a single IncrementalSync execution.
    /// - The task self-nils on completion so lifecycle checks remain accurate.
    ///
    /// Lifecycle:
    /// - Cancelled and nilled by `switchList(to:)` and `clearForSignOut()`.
    @MainActor
    func scheduleReconciliationSync() {
        reconciliationSyncTask?.cancel()
        reconciliationSyncTask = Task { [weak self] in
            // 500 ms debounce — lets rapid-fire events coalesce before hitting the network.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            logVoid(params: (action: "scheduleReconciliationSync.triggered", listId: self.listId))
            await self.runIncrementalSync(suppressHighlight: false)
            self.reconciliationSyncTask = nil
        }
        logVoid(params: (action: "scheduleReconciliationSync.scheduled", listId: listId))
    }

    // MARK: - Membership Observation (FAM-21 Bug Fix)

    /// Startet eine Realtime-Beobachtung auf list_members DELETE-Events für den angegebenen User.
    /// Wird beim Login gestartet und bei Sign-Out via clearForSignOut() gestoppt.
    func startObservingMemberships(userId: UUID) {
        guard let repo = listsRepository else { return }
        membershipUserId = userId  // P9: Cache for reconnect in resumeRealtimeSync()
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
