/*
 SyncEngine+LocalChanges.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lokale Artikel-Änderungen der SyncEngine (anlegen, ändern, löschen, gebündelt, Import, Foto-Umzug) über den gemeinsamen Schreibweg sowie Steuerung der Warteschlange (fortsetzen, erneut versuchen, Liste vergessen, Abmelden).

 📝 Last Change:
 - Aus SyncEngine.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension SyncEngine {
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

    /// Alte Base64-Fotos einer Liste nach Storage umziehen (Migration 016): Foto hochladen, Pfad setzen.
    /// Mehrere Geräte dürfen das gleichzeitig tun – gleiches Foto ergibt gleiche Datei und gleichen Pfad.
    func migrateLegacyImages(listId: UUID) async {
        guard imageStorage != nil,
              let legacy = try? itemStore.itemsWithLegacyImage(listId: listId), !legacy.isEmpty else { return }
        logVoid(params: (action: "migrateLegacyImages", listId: listId, count: legacy.count))
        await write(legacy.map { $0.toItemModel() }, tombstone: false, forceImage: true)
    }

    /// Der gemeinsame Schreibweg: neue HLC je Artikel, lokal speichern, einreihen, senden.
    private func write(_ items: [ItemModel], tombstone: Bool, sendImmediately: Bool = true,
                       forceImage: Bool = false) async {
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
            let imageChanged = !tombstone && (forceImage || existing == nil || existing?.imageData != item.imageData)
            var model = item
            if imageChanged { model.imagePath = nil }            // Pfad bildet prepare() nach dem Hochladen
            do {
                let entity = try itemStore.writeLocal(model, hlc: hlc, tombstone: tombstone, modifiedBy: hlcGenerator.nodeId)
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

    /// Kein Zugriff mehr auf eine Liste: wartende Operationen verwerfen (sie würden nur abgelehnt).
    func forgetList(_ listId: UUID) {
        operationQueue.removeOperations(listId: listId)
        updatePendingCount()
    }

    /// Abmelden: Nichts aus der Warteschlange darf ins nächste Konto gelangen.
    func resetForSignOut() {
        operationQueue.removeAll()
        updatePendingCount()
    }
}
