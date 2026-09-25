/*
 SyncEngine.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zentrale Stelle für jede Artikel-Änderung: lokal schreiben (SwiftData), einreihen, senden.

 🛠 Includes:
 - Lokale Änderungen (einzeln oder gebündelt) mit neuer HLC.
 - Senden der Warteschlange in Stapeln über ItemsRepository.upsertItems (RPC upsert_items_lww).
 - Auswertung der Server-Antwort je Artikel (übernommen, veraltet, abgelehnt).

 🔰 Notes for Beginners:
 - Offline-First: Jede Änderung steht sofort in SwiftData und damit in der Anzeige. Das Netz ist nie
   Voraussetzung. Gesendet wird, sobald eine Verbindung besteht.
 - Löschen ist eine Änderung mit Löschmarkierung (Tombstone) und neuer HLC – kein Sonderweg.
 - Ohne Netz zählen Fehlversuche nicht. Vorher gab die App nach 5 Versuchen (≈ 30–60 s) für immer auf.
 - Nutzer-Logs schreibt diese Klasse nicht (Projektregel); sie meldet `SyncEvent`s an das ViewModel.

 📝 Last Change:
 - Neu aufgebaut (Audit 25.09.2026): ein Schreibweg, Server-LWW, Stapel, Fehlerklassen, keine
   Sonder-Pfade mehr für Anlegen/Löschen/„Alle abhaken“.
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData
import Combine

/// Central sync engine coordinating local writes and the remote queue.
@MainActor
final class SyncEngine: ObservableObject, SyncEngineProtocol {

    // MARK: - Published State

    /// Current sync status for UI feedback
    @Published var syncStatus: SyncStatus = .idle

    /// Number of pending operations
    @Published var pendingOperations: Int = 0

    // MARK: - Configuration

    /// Aufträge je Server-Aufruf (Server-Grenze: 200).
    static let batchSize = 100
    /// Wartezeit, bevor nach einem Verbindungsfehler erneut gesendet wird.
    static let offlineRetryDelay: TimeInterval = 5
    /// Lokale Löschmarkierungen werden nach dieser Zeit entfernt (Server: Cron gc_tombstones, 30 Tage).
    static let tombstoneRetention: TimeInterval = 30 * 24 * 3600

    // MARK: - Dependencies

    private let repository: ItemsRepository
    private let itemStore: SwiftDataItemStore
    private let operationQueue: SyncOperationQueue
    private let hlcGenerator: HybridLogicalClockGenerator
    private let backoffCalculator: BackoffCalculator
    private let syncMonitor: SyncMonitor?
    private let isOnline: @MainActor () -> Bool

    // MARK: - State

    private var queueProcessingTimer: Timer?
    private var isProcessingQueue = false
    private var localWriteObserver: (@MainActor () -> Void)?
    private var syncEventObserver: (@MainActor (SyncEvent) -> Void)?

    // MARK: - Initialization

    init(
        repository: ItemsRepository,
        itemStore: SwiftDataItemStore,
        operationQueue: SyncOperationQueue,
        hlcGenerator: HybridLogicalClockGenerator,
        backoffCalculator: BackoffCalculator = .default,
        syncMonitor: SyncMonitor? = nil,
        isOnline: @escaping @MainActor () -> Bool = { true }
    ) {
        self.repository = repository
        self.itemStore = itemStore
        self.operationQueue = operationQueue
        self.hlcGenerator = hlcGenerator
        self.backoffCalculator = backoffCalculator
        self.syncMonitor = syncMonitor
        self.isOnline = isOnline
        startQueueProcessing()
        updatePendingCount()
    }

    // Mit Swift 5.10+ (SE-0371) läuft deinit einer @MainActor-Klasse auf dem Main Thread.
    deinit {
        queueProcessingTimer?.invalidate()
    }

    // MARK: - Observers

    func setLocalWriteObserver(_ observer: @escaping @MainActor () -> Void) {
        localWriteObserver = observer
    }

    func setSyncEventObserver(_ observer: @escaping @MainActor (SyncEvent) -> Void) {
        syncEventObserver = observer
    }

    // MARK: - Local Changes

    /// Legt einen Artikel an. Die ID ist deterministisch aus (Liste, Name), außer sie ist bereits von
    /// einem Artikel mit anderem Namen belegt (siehe ItemIdentity).
    func createItem(_ item: ItemModel) async {
        var model = item
        if let listIdString = item.listId, let listId = UUID(uuidString: listIdString) {
            model = item.withId(ItemIdentity.newItemId(name: item.name, listId: listId, store: itemStore,
                                                       fallback: UUID(uuidString: item.id)).uuidString)
        }
        await write([model], tombstone: false)
    }

    func updateItem(_ item: ItemModel) async {
        await write([item], tombstone: false)
    }

    func deleteItem(_ item: ItemModel) async {
        await write([item], tombstone: true)
    }

    func deleteItems(_ items: [ItemModel]) async {
        await write(items, tombstone: true)
    }

    /// Mehrere Änderungen in EINEM Speichervorgang und EINEM Sende-Durchlauf (z. B. „Alle abhaken“).
    func applyLocalChanges(_ items: [ItemModel]) async {
        await write(items, tombstone: false)
    }

    /// Import aus der Zwischenablage: Schreiben ohne Senden; der Aufrufer ruft danach `resumeSync()`.
    func applyBulkItems(_ targets: [ImportTarget]) async {
        let models = targets.map { target -> ItemModel in
            switch target {
            case .createNew(let model), .reactivate(let model):
                var fresh = model
                fresh.isChecked = false
                return fresh
            case .update(let model):
                return model
            }
        }
        await write(models, tombstone: false, sendImmediately: false)
    }

    /// Der gemeinsame Schreibweg: neue HLC je Artikel, lokal speichern, einreihen, senden.
    private func write(_ items: [ItemModel], tombstone: Bool, sendImmediately: Bool = true) async {
        var seen = Set<String>()
        for item in items where seen.insert(item.id).inserted {
            guard let uuid = UUID(uuidString: item.id), item.listId != nil else {
                logVoid(params: (action: "write.skip", itemId: item.id, reason: "invalid id or listId"))
                continue
            }
            let existing = try? itemStore.fetchItem(id: uuid)
            // receive(): neue HLC ist größer als die der lokalen Zeile, auch wenn die eigene Uhr nachgeht.
            let hlc = existing.map { hlcGenerator.receive($0.hlc) } ?? hlcGenerator.tick()
            let isNew = existing == nil || existing?.tombstone == true
            let imageChanged = !tombstone && (existing == nil || existing?.imageData != item.imageData)
            do {
                let entity = try itemStore.writeLocal(item, hlc: hlc, tombstone: tombstone, modifiedBy: hlcGenerator.nodeId)
                let type: SyncOperationType = tombstone ? .delete : (isNew ? .create : .update)
                enqueue(entity.toItemModel(), type: type, hlc: hlc, tombstone: tombstone, includeImage: imageChanged)
            } catch {
                logVoid(params: (action: "write.error", itemId: item.id, error: error.localizedDescription))
            }
        }
        saveStore("write")
        updatePendingCount()
        localWriteObserver?()
        if sendImmediately { await processQueue() }
    }

    private func enqueue(_ snapshot: ItemModel, type: SyncOperationType, hlc: HybridLogicalClock,
                         tombstone: Bool, includeImage: Bool) {
        let metadata = CRDTMetadata(hlc: hlc, tombstone: tombstone, lastModifiedBy: hlcGenerator.nodeId)
        do {
            let operation = try SyncOperation.create(type: type, item: snapshot, metadata: metadata)
            operation.includesImage = includeImage
            operationQueue.enqueue(operation)
        } catch {
            logVoid(params: (action: "enqueue.error", itemId: snapshot.id, error: error.localizedDescription))
        }
    }

    // MARK: - Control

    /// Verbindung wieder da / App im Vordergrund: Wartezeiten zurücksetzen und sofort senden.
    func resumeSync() async {
        operationQueue.resetRetryDelays()
        await processQueue()
    }

    /// „Erneut versuchen“ an einem fehlgeschlagenen Artikel.
    func retryItem(_ item: ItemModel) async {
        operationQueue.resetFailedOperation(itemId: item.id)
        if operationQueue.hasPendingOperation(itemId: item.id) {
            if let uuid = UUID(uuidString: item.id), let entity = try? itemStore.fetchItem(id: uuid) {
                entity.syncStatus = entity.tombstone == true ? .pendingDelete : .pendingUpdate
                saveStore("retryItem")
            }
            localWriteObserver?()
            await processQueue()
        } else {
            await write([item], tombstone: false)     // keine Operation mehr da: Stand neu einreihen
        }
    }

    /// Abmelden: Nichts aus der Warteschlange darf ins nächste Konto gelangen.
    func resetForSignOut() {
        operationQueue.removeAll()
        updatePendingCount()
    }

    // MARK: - Queue Processing

    private func processQueue() async {
        guard !isProcessingQueue, operationQueue.count > 0 else { return }
        guard isOnline() else {
            logVoid(params: (action: "processQueue.skip", reason: "offline", pending: operationQueue.count))
            return
        }
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        let initialPending = operationQueue.count
        syncStatus = .syncing
        syncEventObserver?(.started(itemCount: initialPending))

        var sent = 0
        while true {
            let batch = operationQueue.dequeueBatch(limit: Self.batchSize)
            guard !batch.isEmpty else { break }
            let (operations, requests) = prepare(batch)
            guard !requests.isEmpty else { continue }
            let keepGoing = await send(requests, for: operations)
            sent += operations.count
            guard keepGoing else { break }
        }

        syncStatus = .idle
        updatePendingCount()
        localWriteObserver?()
        syncEventObserver?(.completed(itemCount: sent, remaining: operationQueue.count))
    }

    /// Entfernt überholte Operationen und baut die Aufträge für den Server.
    private func prepare(_ batch: [SyncOperation]) -> ([SyncOperation], [ItemUpsertRequest]) {
        var operations: [SyncOperation] = []
        var requests: [ItemUpsertRequest] = []
        for operation in batch {
            guard let snapshot = try? operation.decodeItemSnapshot() else {
                operationQueue.markFailed(operation.id, message: "snapshot unreadable")
                continue
            }
            // Überholt: Eine neuere Remote-Änderung hat lokal schon gewonnen (die Operation ist immer
            // die neueste eigene, siehe SyncOperationQueue.enqueue). Nicht mehr senden.
            if let uuid = UUID(uuidString: operation.itemId), let entity = try? itemStore.fetchItem(id: uuid),
               snapshot.hlc < entity.hlc {
                operationQueue.markSuccess(operation.id)
                continue
            }
            operations.append(operation)
            requests.append(ItemUpsertRequest(item: snapshot, includeImage: operation.includesImage))
        }
        return (operations, requests)
    }

    /// Sendet einen Stapel. - Returns: false, wenn der Durchlauf abbrechen soll (offline/vorübergehend).
    private func send(_ requests: [ItemUpsertRequest], for operations: [SyncOperation]) async -> Bool {
        let monitorId = syncMonitor?.startOperation()
        let start = Date()
        do {
            let results = try await repository.upsertItems(requests)
            guard results.count == operations.count else { throw SyncEngineError.responseCountMismatch }
            for (operation, result) in zip(operations, results) { handle(result, for: operation) }
            saveStore("send")
            if let monitorId { syncMonitor?.endOperation(monitorId, success: true, latency: Date().timeIntervalSince(start)) }
            return true
        } catch {
            if let monitorId { syncMonitor?.endOperation(monitorId, success: false, latency: Date().timeIntervalSince(start)) }
            let kind = SyncErrorClassifier.classify(error)
            logVoid(params: (action: "send.error", kind: "\(kind)", count: operations.count, error: error.localizedDescription))
            for operation in operations { handleFailure(of: operation, kind: kind, error: error) }
            return kind == .permanent
        }
    }

    private func handle(_ result: ItemUpsertResult, for operation: SyncOperation) {
        switch result.status {
        case .applied, .stale:
            operationQueue.markSuccess(operation.id)
            if let row = result.item { _ = try? itemStore.mergeRemote(row, includeImage: false) }
            markSyncedIfSettled(itemId: operation.itemId)
        case .denied, .invalid:
            operationQueue.markFailed(operation.id, message: result.message ?? result.status.rawValue)
            markEntityFailed(itemId: operation.itemId)
        }
    }

    private func handleFailure(of operation: SyncOperation, kind: SyncErrorClassifier.Kind, error: Error) {
        switch kind {
        case .offline:
            operationQueue.deferOperation(operation.id, until: Date().addingTimeInterval(Self.offlineRetryDelay), error: error)
        case .transient:
            // Wartezeit wächst (bis 60 s), aber die Operation gibt nie auf.
            operationQueue.updateRetrySchedule(operation.id, error: error,
                                               backoff: backoffCalculator.delay(for: operation.retryCount),
                                               maxRetries: .max)
        case .permanent:
            operationQueue.markFailed(operation.id, message: error.localizedDescription)
            markEntityFailed(itemId: operation.itemId)
        }
    }

    /// Nach Erfolg: „synchron“, sofern keine neuere eigene Änderung desselben Artikels wartet.
    private func markSyncedIfSettled(itemId: String) {
        guard !operationQueue.hasPendingOperation(itemId: itemId),
              let uuid = UUID(uuidString: itemId), let entity = try? itemStore.fetchItem(id: uuid) else { return }
        entity.syncStatus = .synced
    }

    private func markEntityFailed(itemId: String) {
        guard let uuid = UUID(uuidString: itemId), let entity = try? itemStore.fetchItem(id: uuid) else { return }
        entity.syncStatus = .failed
        syncEventObserver?(.itemFailed(entity.toItemModel()))
    }

    // MARK: - Background Processing

    private func startQueueProcessing() {
        queueProcessingTimer?.invalidate()
        queueProcessingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.processQueue() }
        }
    }

    private func stopQueueProcessing() {
        queueProcessingTimer?.invalidate()
        queueProcessingTimer = nil
    }

    private func updatePendingCount() {
        pendingOperations = operationQueue.count
        syncMonitor?.updateQueueDepth(pendingOperations)
    }

    private func saveStore(_ action: String) {
        do {
            try itemStore.save()
        } catch {
            logVoid(params: (action: "\(action).saveError", error: error.localizedDescription))
        }
    }

    // MARK: - Lifecycle Management

    /// App im Hintergrund: Timer anhalten.
    func pause() {
        stopQueueProcessing()
        syncStatus = .paused
    }

    /// App wieder aktiv: Timer starten, alte Löschmarkierungen aufräumen, sofort senden.
    func resume() {
        startQueueProcessing()
        syncStatus = .idle
        _ = try? itemStore.purgeTombstones(olderThan: Date().addingTimeInterval(-Self.tombstoneRetention))
        Task { await resumeSync() }
    }
}

/// Fehler der SyncEngine selbst (nicht vom Server).
enum SyncEngineError: Error {
    /// Die Server-Antwort hat nicht genau einen Eintrag je Auftrag.
    case responseCountMismatch
}
