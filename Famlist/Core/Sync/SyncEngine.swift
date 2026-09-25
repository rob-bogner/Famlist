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
 - Lokale Änderungen/Steuerung → SyncEngine+LocalChanges.swift, Foto-Upload → SyncEngine+Images.swift,
   SyncEngineError → SyncEngineError.swift ausgelagert (Audit 25.09.2026).
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
    let itemStore: SwiftDataItemStore
    let operationQueue: SyncOperationQueue
    let hlcGenerator: HybridLogicalClockGenerator
    private let backoffCalculator: BackoffCalculator
    private let syncMonitor: SyncMonitor?
    private let isOnline: @MainActor () -> Bool
    /// Hochladen der Fotos vor dem Senden (nil = keine Fotos hochladen, z. B. in Tests).
    let imageStorage: ImageStorage?
    /// Existiert die Liste schon auf dem Server? Artikel offline angelegter Listen warten, bis die
    /// Liste angelegt ist (OfflineListsRepository.isListReady) – sonst lehnt der Server sie ab.
    private let isListReady: @MainActor (UUID) -> Bool

    // MARK: - State

    private var queueProcessingTimer: Timer?
    private var isProcessingQueue = false
    private(set) var localWriteObserver: (@MainActor () -> Void)?
    private var syncEventObserver: (@MainActor (SyncEvent) -> Void)?

    // MARK: - Initialization

    init(
        repository: ItemsRepository,
        itemStore: SwiftDataItemStore,
        operationQueue: SyncOperationQueue,
        hlcGenerator: HybridLogicalClockGenerator,
        backoffCalculator: BackoffCalculator = .default,
        syncMonitor: SyncMonitor? = nil,
        imageStorage: ImageStorage? = nil,
        isOnline: @escaping @MainActor () -> Bool = { true },
        isListReady: @escaping @MainActor (UUID) -> Bool = { _ in true }
    ) {
        self.repository = repository
        self.itemStore = itemStore
        self.operationQueue = operationQueue
        self.hlcGenerator = hlcGenerator
        self.backoffCalculator = backoffCalculator
        self.syncMonitor = syncMonitor
        self.imageStorage = imageStorage
        self.isOnline = isOnline
        self.isListReady = isListReady
        startQueueProcessing()
        updatePendingCount()
    }

    // Kein deinit: Timer ist nicht Sendable und darf im nicht isolierten deinit nicht angefasst werden
    // (isolated deinit braucht das Laufzeitsymbol swift_task_deinitOnExecutor, das nur schwach gelinkt wird und
    // unter iOS 17 fehlen kann). Der Timer beendet sich stattdessen selbst, sobald die Engine
    // freigegeben ist – auf dem Run Loop, auf dem er läuft (siehe startQueueProcessing).

    // MARK: - Observers

    func setLocalWriteObserver(_ observer: @escaping @MainActor () -> Void) {
        localWriteObserver = observer
    }

    func setSyncEventObserver(_ observer: @escaping @MainActor (SyncEvent) -> Void) {
        syncEventObserver = observer
    }

    // MARK: - Queue Processing

    func processQueue() async {
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
            let (operations, requests) = await prepare(batch)
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

    /// Entfernt überholte Operationen, lädt geänderte Fotos hoch und baut die Aufträge für den Server.
    private func prepare(_ batch: [SyncOperation]) async -> ([SyncOperation], [ItemUpsertRequest]) {
        var operations: [SyncOperation] = []
        var requests: [ItemUpsertRequest] = []
        let ids = batch.map(\.id)                 // vor dem ersten Warten (Foto-Upload) kopieren
        for (id, operation) in zip(ids, batch) {
            // Während eines Uploads kann die Warteschlange geleert worden sein (Abmelden) → nicht mehr anfassen.
            guard operationQueue.contains(id) else { continue }
            guard var snapshot = try? operation.decodeItemSnapshot() else {
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
            if !isListReady(operation.listId) {
                operationQueue.deferOperation(operation.id, until: Date().addingTimeInterval(Self.offlineRetryDelay),
                                              error: SyncEngineError.listNotYetCreated)
                continue
            }
            if operation.includesImage {
                let sent = SentOperation(operation)
                do {
                    snapshot.imagePath = try await uploadImage(of: snapshot)
                } catch {
                    handleFailure(of: sent, kind: SyncErrorClassifier.classify(error), error: error)
                    continue
                }
                guard operationQueue.contains(id) else { continue }
            }
            operations.append(operation)
            requests.append(ItemUpsertRequest(item: snapshot, includeImage: operation.includesImage))
        }
        return (operations, requests)
    }

    /// Sendet einen Stapel. - Returns: false, wenn der Durchlauf abbrechen soll (offline/vorübergehend).
    private func send(_ requests: [ItemUpsertRequest], for models: [SyncOperation]) async -> Bool {
        // Werte VOR dem Warten kopieren: Wird die Warteschlange währenddessen geleert (Abmelden), wären die
        // SwiftData-Objekte gelöscht, und schon das Lesen ihrer Felder kann abstürzen.
        let operations = models.map(SentOperation.init)
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

    private func handle(_ result: ItemUpsertResult, for operation: SentOperation) {
        // Antwort kam nach dem Abmelden bzw. nachdem die Liste vergessen wurde: nichts mehr anlegen,
        // sonst stünden Artikel des alten Kontos wieder in der geleerten Datenbank (Audit 2, Befund S5).
        guard operationQueue.contains(operation.id) else {
            logVoid(params: (action: "send.resultDiscarded", itemId: operation.itemId))
            return
        }
        switch result.status {
        case .applied, .stale:
            operationQueue.markSuccess(operation.id)
            if let row = result.item { _ = try? itemStore.mergeRemote(row, legacyImageKnown: false) }
            markSyncedIfSettled(itemId: operation.itemId)
        case .denied, .invalid:
            operationQueue.markFailed(operation.id, message: result.message ?? result.status.rawValue)
            markEntityFailed(itemId: operation.itemId)
        }
    }

    private func handleFailure(of operation: SentOperation, kind: SyncErrorClassifier.Kind, error: Error) {
        guard operationQueue.contains(operation.id) else { return }
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
        queueProcessingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard self != nil else { timer.invalidate(); return } // Engine freigegeben → Timer beenden.
            Task { @MainActor [weak self] in await self?.processQueue() }
        }
    }

    private func stopQueueProcessing() {
        queueProcessingTimer?.invalidate()
        queueProcessingTimer = nil
    }

    func updatePendingCount() {
        pendingOperations = operationQueue.count
        syncMonitor?.updateQueueDepth(pendingOperations)
    }

    func saveStore(_ action: String) {
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
