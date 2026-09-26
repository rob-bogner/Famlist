/*
 SupabaseItemsRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-backed implementation of ItemsRepository.
 - Core class: dependencies, Realtime observation, fetchAndYield, pagination, incremental sync.
 - Der einzige Schreibweg (upsertItems) liegt in SupabaseItemsRepository+CRUD.swift.

 🛠 Includes:
 - observeItems: AsyncStream backed by Realtime subscriptions.
 - keepListsInSync: Realtime-Kanäle aller Listen offen halten, auch ohne Beobachter (Watch-Plan Phase 3).
 - processRealtimeEvent: routes INSERT/UPDATE/DELETE to RealtimeEventProcessor; no full refetch.
 - Abfragen (Seiten, Delta, IDs) → SupabaseItemsRepository+Fetch.swift.
 - refreshLocalAndYield: reads from SwiftData and yields to stream observers.

 🔰 Notes for Beginners:
 - Realtime events are processed granularly; fetchAndYield is no longer called after every event.
 - SyncOrchestrator buffers Realtime handlers during active page loads (FAM-79).

 📝 Last Change:
 - Realtime für alle Listen: Ein Kanal je Liste läuft, solange die Liste beobachtet wird ODER in
   keepListsInSync steht. Übernommene Änderungen meldet setRemoteChangeHandler (gebündelt, ohne Echos).
   Delta-Abfrage für mehrere Listen in einem Aufruf (Watch-Plan Phase 3, 26.09.2026).
 ------------------------------------------------------------------------
*/

import Foundation
import Supabase

// MARK: - SupabaseItemsRepository

/// Supabase-backed items repository implementing ItemsRepository.
/// @MainActor ensures that all mutable properties (continuations, gate) are
/// accessed exclusively on the main thread, preventing Data Races.
@MainActor
final class SupabaseItemsRepository: ItemsRepository {

    // MARK: - Dependencies

    let client: SupabaseClienting
    private let realtimeManager: SupabaseRealtimeManager
    private let eventProcessor: RealtimeEventProcessor

    /// Local SwiftData store — used to yield locally-sourced snapshots after Realtime events.
    private let itemStore: SwiftDataItemStore

    /// Orchestrator that serialises PageLoader and Realtime event processing.
    /// Optional for backward compatibility (nil in tests that don't inject it).
    var syncOrchestrator: SyncOrchestrator?

    // MARK: - State

    /// Meldung „Realtime wieder verbunden“ an die Liste (Delta-Abgleich).
    private var reconnectHandler: (@MainActor (UUID) -> Void)?

    func setReconnectHandler(_ handler: @escaping @MainActor (UUID) -> Void) {
        reconnectHandler = handler
    }

    /// Active continuations keyed by listId → unique observer token.
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]
    /// Geplantes, zusammengefasstes Neuladen je Liste (siehe scheduleRefresh).
    private var pendingRefresh: [UUID: Task<Void, Never>] = [:]
    /// Seit dem letzten Bündel übernommene Artikel-IDs je Liste (für den remoteChangeHandler).
    private var pendingRemoteChanges: [UUID: Set<String>] = [:]
    /// Listen, deren Kanal auch ohne Beobachter offen bleibt (keepListsInSync).
    private var syncedListIds: Set<UUID> = []
    /// Listen mit angemeldetem (oder gerade anmeldendem) Realtime-Kanal (lesbar für Tests).
    private(set) var subscribedListIds: Set<UUID> = []
    /// Meldung „Änderung von außen übernommen“ (Liste, Artikel-IDs).
    private var remoteChangeHandler: (@MainActor (UUID, Set<String>) -> Void)?

    func setRemoteChangeHandler(_ handler: @escaping @MainActor (UUID, Set<String>) -> Void) {
        remoteChangeHandler = handler
    }
    /// 80 ms: für Nutzer nicht spürbar, fasst aber einen Stapel Realtime-Ereignisse zusammen.
    static let refreshCoalescingDelay: UInt64 = 80_000_000

    // MARK: - Lifecycle

    init(
        client: SupabaseClienting,
        itemStore: SwiftDataItemStore,
        syncOrchestrator: SyncOrchestrator? = nil
    ) {
        self.client = client
        self.itemStore = itemStore
        self.realtimeManager = SupabaseRealtimeManager(client: client)
        self.eventProcessor = RealtimeEventProcessor(itemStore: itemStore)
        self.syncOrchestrator = syncOrchestrator
    }

    // MARK: - Observation

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        let stream = AsyncStream { continuation in
            let token = UUID()
            if continuations[listId] == nil {
                continuations[listId] = [:]
            }
            continuations[listId]?[token] = continuation

            // Set up Realtime subscription if this is the first observer for this list.
            if self.continuations[listId]?.count == 1 {
                self.ensureChannel(for: listId)
            }

            // onTermination can be called on any thread; dispatch back to MainActor.
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.continuations[listId]?.removeValue(forKey: token)
                    if self.continuations[listId]?.isEmpty == true {
                        self.continuations.removeValue(forKey: listId)
                        self.releaseChannelIfUnused(listId)
                    }
                }
            }
            // Note: No initial fetchAndYield() here (FAM-41).
            // Initial data is provided by loadLocalSnapshot() + runIncrementalSync() in ListViewModel.
        }
        return logResult(params: ["listId": listId], result: stream)
    }

    private func yield(_ listId: UUID, _ items: [ItemModel]) {
        continuations[listId]?.values.forEach { $0.yield(items) }
    }

    // MARK: - Channels (alle Listen)

    func keepListsInSync(_ listIds: Set<UUID>) {
        let previous = syncedListIds
        syncedListIds = listIds
        listIds.subtracting(previous).forEach(ensureChannel)
        previous.subtracting(listIds).forEach(releaseChannelIfUnused)
        logVoid(params: (action: "keepListsInSync", count: listIds.count, channels: subscribedListIds.count))
    }

    /// Meldet den Kanal einer Liste an, falls er noch nicht läuft. Die Anmeldung startet in einer Aufgabe;
    /// wird die Liste vorher wieder freigegeben, unterbleibt sie.
    private func ensureChannel(for listId: UUID) {
        guard subscribedListIds.insert(listId).inserted else { return }
        Task { @MainActor [weak self] in
            guard let self, self.subscribedListIds.contains(listId) else { return }
            await self.realtimeManager.setupRealtimeChannel(
                for: listId,
                onEvent: { [weak self] event in await self?.processRealtimeEvent(event, listId: listId) },
                onResubscribed: { [weak self] in self?.reconnectHandler?(listId) }
            )
        }
    }

    /// Meldet den Kanal ab, wenn die Liste weder beobachtet wird noch in keepListsInSync steht.
    private func releaseChannelIfUnused(_ listId: UUID) {
        guard subscribedListIds.contains(listId), !syncedListIds.contains(listId),
              continuations[listId]?.isEmpty ?? true else { return }
        subscribedListIds.remove(listId)
        realtimeManager.teardownRealtimeChannel(for: listId)
    }

    // MARK: - Realtime Event Processing

    /// Routes a Realtime event to the event processor, respecting SyncOrchestrator buffering.
    func processRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
        // Extract a stable item id for SyncOrchestrator coalescing.
        let itemId = extractItemId(from: event) ?? UUID().uuidString

        // SyncOrchestrator: buffer during page loads, process immediately otherwise.
        if let orchestrator = syncOrchestrator {
            await orchestrator.enqueueOrProcess(itemId: itemId) { [weak self] in
                await self?.handleRealtimeEvent(event, listId: listId)
            }
        } else {
            await handleRealtimeEvent(event, listId: listId)
        }
    }

    /// Processes a Realtime event and yields the updated local snapshot to stream observers.
    private func handleRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
        var changed = true
        switch event {
        case .insert(let payload), .update(let payload):
            // Echo der eigenen Änderung (gleiche HLC) → ignoriert, nicht als fremde Änderung melden.
            changed = eventProcessor.processUpsert(payload, listId: listId) != .ignored
        case .delete(let payload):
            await eventProcessor.processDeletion(payload, listId: listId)
        }
        if changed, let itemId = extractItemId(from: event) {
            pendingRemoteChanges[listId, default: []].insert(itemId.uppercased())
        }

        // FAM-41: yield from SwiftData (local truth), not from a full remote refetch.
        scheduleRefresh(listId)
    }

    /// Fasst Neuladen zusammen: Viele Ereignisse kurz hintereinander (z. B. 200× „abgehakt“ von einem anderen
    /// Gerät) laden die Liste danach EINMAL statt 200-mal komplett aus SwiftData (Audit 2, Befund Q4).
    /// Ebenso gebündelt: die Meldung an den remoteChangeHandler.
    private func scheduleRefresh(_ listId: UUID) {
        guard pendingRefresh[listId] == nil else { return }
        pendingRefresh[listId] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.refreshCoalescingDelay)
            guard let self else { return }
            self.pendingRefresh[listId] = nil
            if self.continuations[listId]?.isEmpty == false { self.refreshLocalAndYield(listId) }
            if let changed = self.pendingRemoteChanges.removeValue(forKey: listId), !changed.isEmpty {
                self.remoteChangeHandler?(listId, changed)
            }
        }
    }

    /// Reads the current list from SwiftData and yields it to all stream observers for this list.
    func refreshLocalAndYield(_ listId: UUID) {
        do {
            let localItems = try itemStore.fetchItems(listId: listId).map { $0.toItemModel() }
            yield(listId, localItems)
            logVoid(params: (action: "refreshLocalAndYield", listId: listId, count: localItems.count))
        } catch {
            logVoid(params: (action: "refreshLocalAndYield.error", listId: listId, error: error.localizedDescription))
        }
    }

    // MARK: - Helpers

    /// Extracts the item id string from a Realtime event payload for SyncOrchestrator coalescing.
    private func extractItemId(from event: RealtimeEvent) -> String? {
        func extractFromPayload(_ payload: [String: Any]) -> String? {
            let record = (payload["record"] as? [String: Any]) ?? (payload["old_record"] as? [String: Any])
            return record?["id"] as? String
        }
        switch event {
        case .insert(let p), .update(let p), .delete(let p):
            return extractFromPayload(p)
        }
    }
}
