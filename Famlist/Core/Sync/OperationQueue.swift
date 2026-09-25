/*
 OperationQueue.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dauerhafte Warteschlange der Sync-Operationen (SwiftData).

 🛠 Includes:
 - enqueue mit Zusammenfassen: pro Artikel höchstens EINE wartende Operation (die neueste).
 - Stapel-Entnahme (dequeueBatch) für das gebündelte Senden über die RPC upsert_items_lww.
 - Vorübergehende Fehler (offline, 5xx) ohne Versuchszähler; dauerhafte Fehler markieren „fehlgeschlagen“.

 🔰 Notes for Beginners:
 - Jede Operation trägt den VOLLEN Stand des Artikels (inkl. Löschmarkierung und HLC). Deshalb reicht
   die neueste: Zwischenstände müssen nicht einzeln zum Server.
 - „In Arbeit“ (inFlight): Diese Operation ist gerade unterwegs. Eine neue Änderung desselben Artikels
   ersetzt sie nicht, sondern wartet dahinter. Sonst ginge die neue Änderung beim Erfolg der alten verloren.
 - Die Reihenfolge pro Artikel ist damit garantiert: Es ist nie mehr als eine Operation je Artikel unterwegs.

 📝 Last Change:
 - Zusammenfassen, Stapel, In-Arbeit-Schutz, Fehlerklassen (Audit 25.09.2026, K2/H1/H2).
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Manages a persistent queue of sync operations backed by SwiftData
@MainActor
final class SyncOperationQueue {

    // MARK: - Dependencies

    private let context: ModelContext

    /// Operationen, die gerade gesendet werden (nur im Speicher; nach einem Neustart ist nichts unterwegs).
    private(set) var inFlight: Set<UUID> = []

    // MARK: - Initialization

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Enqueue

    /// Reiht eine Operation ein und ersetzt dabei wartende (nicht laufende) Operationen desselben Artikels.
    func enqueue(_ operation: SyncOperation) {
        for existing in fetch(itemId: operation.itemId) where !inFlight.contains(existing.id) {
            context.delete(existing)
        }
        context.insert(operation)
        saveOrLog("enqueueOperation", operationId: operation.id)
    }

    // MARK: - Dequeue

    /// Nächste sendebereite Operation (älteste zuerst), deren Artikel nicht gerade unterwegs ist.
    func dequeue() -> SyncOperation? {
        dequeueBatch(limit: 1).first
    }

    /// Bis zu `limit` sendebereite Operationen, höchstens eine je Artikel, und markiert sie als „in Arbeit“.
    func dequeueBatch(limit: Int) -> [SyncOperation] {
        let busyItems = Set(fetchAll().filter { inFlight.contains($0.id) }.map(\.itemId))
        var seen = busyItems
        var batch: [SyncOperation] = []
        for operation in fetchPending() where operation.isReadyForRetry && !inFlight.contains(operation.id) {
            guard !seen.contains(operation.itemId) else { continue }
            seen.insert(operation.itemId)
            batch.append(operation)
            if batch.count == limit { break }
        }
        batch.forEach { inFlight.insert($0.id) }
        return batch
    }

    // MARK: - Completion

    /// Erfolg: Operation entfernen.
    func markSuccess(_ operationId: UUID) {
        inFlight.remove(operationId)
        remove(operationId)
    }

    /// Vorübergehender Fehler (offline, Zeitüberschreitung, 5xx): später erneut, ohne Versuchszähler.
    func deferOperation(_ operationId: UUID, until date: Date, error: Error) {
        inFlight.remove(operationId)
        guard let operation = fetch(id: operationId) else { return }
        operation.nextRetryAt = date
        operation.lastAttemptAt = Date()
        operation.lastErrorMessage = error.localizedDescription
        saveOrLog("deferOperation", operationId: operationId)
    }

    /// Fehler mit Versuchszähler und Wartezeit. Nach `maxRetries` gilt die Operation als fehlgeschlagen.
    func updateRetrySchedule(_ operationId: UUID, error: Error, backoff: TimeInterval,
                             maxRetries: Int = BackoffCalculator.default.maxRetries) {
        inFlight.remove(operationId)
        guard let operation = fetch(id: operationId) else { return }
        operation.recordFailure(error: error, backoff: backoff, maxRetries: maxRetries)
        saveOrLog("updateRetrySchedule", operationId: operationId)
    }

    /// Dauerhafter Fehler (kein Zugriff, ungültige Daten): sofort „fehlgeschlagen“.
    func markFailed(_ operationId: UUID, message: String) {
        inFlight.remove(operationId)
        guard let operation = fetch(id: operationId) else { return }
        operation.hasFailed = true
        operation.nextRetryAt = nil
        operation.lastAttemptAt = Date()
        operation.lastErrorMessage = message
        saveOrLog("markFailed", operationId: operationId)
    }

    /// Gibt eine unterwegs abgebrochene Operation wieder frei (z. B. nach Abbruch des Durchlaufs).
    func release(_ operationId: UUID) {
        inFlight.remove(operationId)
    }

    // MARK: - Queries

    /// Gibt es für den Artikel noch eine Operation (wartend oder unterwegs, nicht fehlgeschlagen)?
    func hasPendingOperation(itemId: String) -> Bool {
        fetch(itemId: itemId).contains { !$0.hasFailed }
    }

    /// All operations (for monitoring/debugging), oldest first.
    func peek() -> [SyncOperation] {
        fetchAll()
    }

    /// Pending operations for a specific list.
    func operations(for listId: UUID) -> [SyncOperation] {
        fetchPending().filter { $0.listId == listId }
    }

    /// Number of pending (not failed) operations.
    var count: Int {
        (try? context.fetchCount(FetchDescriptor<SyncOperation>(predicate: #Predicate { !$0.hasFailed }))) ?? 0
    }

    /// Number of permanently failed operations.
    var failedCount: Int {
        (try? context.fetchCount(FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.hasFailed }))) ?? 0
    }

    /// Frühester Zeitpunkt, zu dem eine wartende Operation wieder sendebereit ist (nil = keine wartet).
    var nextRetryDate: Date? {
        fetchPending().compactMap { $0.isReadyForRetry ? Date.distantPast : $0.nextRetryAt }.min()
    }

    // MARK: - Removal

    /// Removes an operation from the queue.
    func remove(_ operationId: UUID) {
        inFlight.remove(operationId)
        guard let operation = fetch(id: operationId) else { return }
        context.delete(operation)
        saveOrLog("removeOperation", operationId: operationId)
    }

    /// Entfernt wartende Operationen eines Artikels (z. B. weil eine neuere Remote-Änderung gewonnen hat).
    func dropPendingOperations(itemId: String) {
        let stale = fetch(itemId: itemId).filter { !inFlight.contains($0.id) }
        guard !stale.isEmpty else { return }
        stale.forEach { context.delete($0) }
        saveOrLog("dropPendingOperations", operationId: nil)
    }

    /// Resets a permanently-failed operation so it is eligible for retry.
    func resetFailedOperation(itemId: String) {
        let failed = fetch(itemId: itemId).filter(\.hasFailed)
        for operation in failed {
            operation.hasFailed = false
            operation.retryCount = 0
            operation.nextRetryAt = nil
            operation.lastErrorMessage = nil
        }
        saveOrLog("resetFailedOperation", operationId: nil)
    }

    /// Setzt alle Wartezeiten zurück (Verbindung ist wieder da): alles sofort sendebereit.
    func resetRetryDelays() {
        let waiting = fetchPending().filter { $0.nextRetryAt != nil }
        guard !waiting.isEmpty else { return }
        waiting.forEach { $0.nextRetryAt = nil }
        saveOrLog("resetRetryDelays", operationId: nil)
    }

    /// Clears all failed operations (for manual cleanup).
    func clearFailed() {
        let failed = (try? context.fetch(FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.hasFailed }))) ?? []
        failed.forEach { context.delete($0) }
        saveOrLog("clearFailedOperations", operationId: nil)
    }

    /// Entfernt alle Operationen einer Liste (kein Zugriff mehr, z. B. aus der Liste entfernt).
    func removeOperations(listId: UUID) {
        let affected = fetchAll().filter { $0.listId == listId }
        guard !affected.isEmpty else { return }
        affected.forEach { inFlight.remove($0.id); context.delete($0) }
        saveOrLog("removeOperationsForList", operationId: nil)
    }

    /// Entfernt ALLE Operationen (Abmelden: nichts darf ins nächste Konto gelangen).
    func removeAll() {
        inFlight.removeAll()
        fetchAll().forEach { context.delete($0) }
        saveOrLog("removeAllOperations", operationId: nil)
    }

    // MARK: - Private

    private func fetchAll() -> [SyncOperation] {
        let descriptor = FetchDescriptor<SyncOperation>(sortBy: [SortDescriptor(\SyncOperation.createdAt, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchPending() -> [SyncOperation] {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { !$0.hasFailed },
            sortBy: [SortDescriptor(\SyncOperation.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetch(id: UUID) -> SyncOperation? {
        let descriptor = FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetch(itemId: String) -> [SyncOperation] {
        let descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.itemId == itemId },
            sortBy: [SortDescriptor(\SyncOperation.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func saveOrLog(_ action: String, operationId: UUID?) {
        do {
            if context.hasChanges { try context.save() }
        } catch {
            logVoid(params: (action: "\(action).error", operationId: operationId?.uuidString ?? "-",
                             error: error.localizedDescription))
        }
    }
}
