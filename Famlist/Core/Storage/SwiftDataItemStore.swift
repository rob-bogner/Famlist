/*
 SwiftDataItemStore.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Convenience wrapper handling ItemEntity persistence via SwiftData ModelContext.
 🛠 Includes: Fetch, upsert, delete, and list-scoped queries for items.
 🔰 Notes for Beginners: Keep SwiftData specifics here so view models and repositories stay clean.
 📝 Last Change: Zwei klare Schreibwege (Audit 25.09.2026): writeLocal() für eigene Änderungen,
   mergeRemote() für Zeilen vom Server (entscheidet per ItemSyncPolicy). Löschmarkierungen bleiben
   lokal erhalten und werden erst nach 30 Tagen entfernt (wie gc_tombstones auf dem Server).
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID and Date.
import SwiftData // Supplies ModelContext, FetchDescriptor, and predicate helpers.

/// Lightweight store that encapsulates SwiftData operations for ItemEntity.
@MainActor
final class SwiftDataItemStore {
    /// Underlying SwiftData context used to perform CRUD.
    private let context: ModelContext

    /// Creates the store with the given ModelContext.
    /// - Parameter context: SwiftData context injected from the view hierarchy or composition root.
    init(context: ModelContext) {
        self.context = context
    }

    /// Fetches items belonging to a specific list identifier.
    /// - Parameter listId: The parent list UUID.
    /// - Returns: Array of ItemEntity ordered by creation date.
    func fetchItems(listId: UUID, includeDeleted: Bool = false) throws -> [ItemEntity] {
        let predicate: Predicate<ItemEntity>
        if includeDeleted {
            predicate = #Predicate { entity in
                entity.listId == listId
            }
        } else {
            predicate = #Predicate { entity in
                entity.listId == listId && entity.deletedAt == nil
            }
        }
        let descriptor = FetchDescriptor<ItemEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\ItemEntity.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches a single item by its identifier.
    /// - Parameter id: Item UUID to load.
    /// - Returns: Matching ItemEntity if present.
    func fetchItem(id: UUID) throws -> ItemEntity? {
        let descriptor = FetchDescriptor<ItemEntity>(
            predicate: #Predicate { $0.id == id },
            sortBy: []
        )
        return try context.fetch(descriptor).first
    }

    /// Ergebnis von `mergeRemote`.
    enum RemoteMergeResult: Equatable {
        case inserted
        case applied
        case ignored
    }

    /// Legt eine Zeile ungeprüft an oder überschreibt sie (Tests, Vorschau-Daten).
    /// App-Code nutzt `writeLocal` bzw. `mergeRemote`.
    @discardableResult
    func upsert(model: ItemModel, listReference: ListEntity? = nil) throws -> ItemEntity {
        let resolvedId = UUID(uuidString: model.id) ?? UUID()
        if let existing = try fetchItem(id: resolvedId) {
            existing.apply(model: model)
            if let listReference { existing.list = listReference }
            return existing
        }
        let entity = ItemEntity.make(from: model, listReference: listReference)
        context.insert(entity)
        return entity
    }

    /// Gleicht eine Zeile vom Server (Realtime, Delta-Sync, Seitenladen, Antwort der RPC) ab.
    /// Sie wird nur übernommen, wenn sie neuer ist als die lokale Zeile (ItemSyncPolicy).
    /// Speichert nicht – der Aufrufer ruft `save()` einmal am Ende.
    @discardableResult
    func mergeRemote(_ model: ItemModel, imagePathKnown: Bool = true, legacyImageKnown: Bool = true) throws -> RemoteMergeResult {
        guard let id = UUID(uuidString: model.id) else { return .ignored }
        let existing = try fetchItem(id: id)
        switch ItemSyncPolicy.decide(local: existing?.hlc, remote: model.hlc) {
        case .insert:
            context.insert(ItemEntity.make(from: model))
            return .inserted
        case .applyRemote:
            existing?.apply(model: model, imagePathKnown: imagePathKnown, legacyImageKnown: legacyImageKnown)
            return .applied
        case .keepLocal:
            return .ignored
        }
    }

    /// Schreibt eine eigene Änderung (Anlegen, Bearbeiten, Löschen) mit neuer HLC.
    /// Status: pendingCreate (neu oder wieder angelegt), pendingDelete (Löschmarkierung), sonst pendingUpdate.
    @discardableResult
    func writeLocal(_ model: ItemModel, hlc: HybridLogicalClock, tombstone: Bool, modifiedBy: String) throws -> ItemEntity {
        let id = UUID(uuidString: model.id) ?? UUID()
        let existing = try fetchItem(id: id)
        let entity: ItemEntity
        if let existing {
            entity = existing
            entity.assignContent(from: model)
        } else {
            entity = ItemEntity.make(from: model)
            context.insert(entity)
        }
        let wasHidden = existing == nil || existing?.tombstone == true
        entity.hlcTimestamp = hlc.timestamp
        entity.hlcCounter = hlc.counter
        entity.hlcNodeId = hlc.nodeId
        entity.lastModifiedBy = modifiedBy
        entity.setTombstone(tombstone)
        if tombstone {
            entity.syncStatus = .pendingDelete
        } else if wasHidden {
            entity.setSyncStatus(.pendingCreate)
        } else {
            entity.setSyncStatus(.pendingUpdate)
        }
        return entity
    }

    /// Artikel (alle Listen), deren Foto einen Storage-Pfad hat, aber noch nicht lokal vorliegt.
    func itemsMissingImage(limit: Int) throws -> [ItemEntity] {
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.imagePath != nil })
        return Array(try context.fetch(descriptor)
            .filter { $0.imageData == nil && $0.deletedAt == nil }
            .prefix(limit))
    }

    /// Artikel einer Liste mit altem Base64-Foto ohne Storage-Pfad (Umzug nach Storage, Migration 016).
    func itemsWithLegacyImage(listId: UUID) throws -> [ItemEntity] {
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.listId == listId })
        return try context.fetch(descriptor).filter { $0.imagePath == nil && $0.imageData != nil && $0.deletedAt == nil }
    }

    /// Entfernt lokale Löschmarkierungen, die bestätigt und älter als `cutoff` sind.
    /// Der Server löscht seine nach 30 Tagen (Cron gc_tombstones); danach braucht sie niemand mehr.
    @discardableResult
    func purgeTombstones(olderThan cutoff: Date) throws -> Int {
        let synced = ItemEntity.SyncStatus.synced.rawValue
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.deletedAt != nil })
        let candidates = try context.fetch(descriptor).filter {
            $0.tombstone == true && $0.syncStatus.rawValue == synced && ($0.deletedAt ?? .distantFuture) < cutoff
        }
        candidates.forEach { context.delete($0) }
        try save()
        return candidates.count
    }

    /// Entfernt ALLE lokalen Artikel einer Liste (inkl. Löschmarkierungen und Foto-Kopien) –
    /// z. B. nach dem Entfernen aus einer geteilten Liste. - Returns: Anzahl entfernter Zeilen.
    @discardableResult
    func purgeAll(listId: UUID) throws -> Int {
        let rows = try fetchItems(listId: listId, includeDeleted: true)
        rows.forEach { context.delete($0) }
        try save()
        return rows.count
    }

    /// Removes an item from the context once the remote delete has been confirmed.
    func purge(id: UUID) throws {
        guard let entity = try fetchItem(id: id) else { return }
        context.delete(entity)
        try save()
    }

    /// Persists outstanding changes on the context.
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
