/*
 ItemEntity+Mapping.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview: Bridges ItemEntity <-> ItemModel for the local-first data pipeline.
 🛠 Includes: Helper methods to convert between SwiftData entities and the existing ItemModel struct.
 🔰 Notes for Beginners: Use these helpers to keep mapping logic consistent across repositories and sync jobs.
 📝 Last Change: apply(model:) ohne Sonderregeln – ob eine Remote-Zeile gewinnt, entscheidet allein
   ItemSyncPolicy (HLC-Vergleich). Löschmarkierung und Sichtbarkeit (deletedAt) laufen synchron.
 ------------------------------------------------------------------------
*/

import Foundation // Needed for UUID conversion between String and UUID representations.

/// Mapping helpers from ItemEntity (SwiftData) to ItemModel (shared model for UI/network).
extension ItemEntity {
    /// Builds an ItemModel snapshot from the SwiftData entity, including CRDT metadata.
    /// - Returns: A fully populated ItemModel instance.
    func toItemModel() -> ItemModel {
        ItemModel(
            id: id.uuidString,
            imageUrl: nil,
            imageData: imageData,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            isUnavailable: isUnavailable,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId.uuidString,
            ownerPublicId: ownerPublicId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            hlcTimestamp: hlcTimestamp,
            hlcCounter: hlcCounter,
            hlcNodeId: hlcNodeId,
            tombstone: tombstone,
            lastModifiedBy: lastModifiedBy,
            isSyncFailed: syncStatus == .failed
        )
    }

    /// HLC dieser Zeile; fehlende Werte (Altbestand) zählen als Epoche 0 und verlieren jeden Vergleich.
    var hlc: HybridLogicalClock {
        HybridLogicalClock(timestamp: hlcTimestamp ?? 0, counter: hlcCounter ?? 0, nodeId: hlcNodeId ?? "")
    }

    /// Übernimmt Inhalt und CRDT-Felder einer gewonnenen Remote-Zeile und markiert sie als synchron.
    /// Ob die Zeile gewinnt, entscheidet vorher `ItemSyncPolicy` – hier gibt es keine Sonderregeln mehr.
    /// - Parameter includeImage: false, wenn die Quelle das Foto nicht mitschickt (Realtime-UPDATE ohne
    ///   unverändertes TOAST-Feld, Antwort der RPC upsert_items_lww): Dann bleibt das lokale Foto.
    func apply(model: ItemModel, includeImage: Bool = true) {
        assignContent(from: model, includeImage: includeImage)
        if let newCreatedAt = model.createdAt { self.createdAt = newCreatedAt }
        if let newUpdatedAt = model.updatedAt { self.updatedAt = newUpdatedAt }
        self.hlcTimestamp = model.hlcTimestamp ?? 0
        self.hlcCounter = model.hlcCounter ?? 0
        self.hlcNodeId = model.hlcNodeId ?? ""
        self.lastModifiedBy = model.lastModifiedBy
        setTombstone(model.tombstone ?? false)
        self.syncStatus = .synced
    }

    /// Schreibt die sichtbaren Felder eines Artikels (ohne CRDT- und Sync-Felder).
    func assignContent(from model: ItemModel, includeImage: Bool = true) {
        if ownerPublicId == nil { self.ownerPublicId = model.ownerPublicId }
        if includeImage { self.imageData = model.imageData }
        self.name = model.name
        self.units = model.units
        self.measure = model.measure
        self.price = model.price
        self.isChecked = model.isChecked
        self.isUnavailable = model.isUnavailable
        self.category = model.category
        self.productDescription = model.productDescription
        self.brand = model.brand
    }

    /// Löschmarkierung setzen; `deletedAt` blendet den Artikel in allen Abfragen aus.
    func setTombstone(_ isTombstoned: Bool) {
        tombstone = isTombstoned
        if isTombstoned {
            if deletedAt == nil { deletedAt = Date() }
        } else {
            deletedAt = nil
        }
    }

    /// Creates a new ItemEntity mirroring the provided ItemModel.
    /// - Parameters:
    ///   - model: Source ItemModel we want to persist locally.
    ///   - listReference: Optional ListEntity reference for immediate relationship wiring.
    /// - Returns: ItemEntity populated with synced status.
    static func make(from model: ItemModel, listReference: ListEntity? = nil) -> ItemEntity {
        let resolvedId = UUID(uuidString: model.id) ?? UUID()
        let resolvedListId = model.listId.flatMap(UUID.init(uuidString:)) ?? listReference?.id ?? UUID()
        let entity = ItemEntity(
            id: resolvedId,
            listId: resolvedListId,
            ownerPublicId: model.ownerPublicId,
            imageData: model.imageData,
            name: model.name,
            units: model.units,
            measure: model.measure,
            price: model.price,
            isChecked: model.isChecked,
            isUnavailable: model.isUnavailable,
            category: model.category,
            productDescription: model.productDescription,
            brand: model.brand,
            createdAt: model.createdAt ?? Date(),
            updatedAt: model.updatedAt ?? Date(),
            deletedAt: nil,
            list: listReference,
            syncStatus: .synced,
            // Fallback epoch=0 is consistent with extractMetadataFromEntity's remote fallback.
            // Using current time here would make a newly-inserted entity (hlcTimestamp==nil)
            // appear causally newer than any remote HLC → CRDT always rejects remote updates (Bug 1).
            hlcTimestamp: model.hlcTimestamp ?? 0,
            hlcCounter: model.hlcCounter ?? 0,
            hlcNodeId: model.hlcNodeId ?? "",
            tombstone: model.tombstone ?? false,
            lastModifiedBy: model.lastModifiedBy
        )
        entity.setTombstone(model.tombstone ?? false)
        return entity
    }
}
