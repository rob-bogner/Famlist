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
    @MainActor
    func runIncrementalSync() async {
        let since = loadLastSyncTimestamp()
        logVoid(params: (action: "runIncrementalSync.start", listId: listId, since: since))

        do {
            let deltaItems = try await repository.fetchItemsSince(listId: listId, since: since)

            var maxUpdatedAt: Date? = nil
            for item in deltaItems {
                if item.tombstone == true {
                    applyRemoteTombstoneModel(item)
                } else {
                    try? itemStore.upsert(model: item)
                    if let updatedAt = item.updatedAt {
                        maxUpdatedAt = maxUpdatedAt.map { max($0, updatedAt) } ?? updatedAt
                    }
                }
            }
            try? itemStore.save()

            // Update high-water mark only when at least one non-tombstone item was received.
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
            // On failure: do not advance lastSyncTimestamp; keep cached data visible.
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
