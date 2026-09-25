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
            imagePath: imagePath,
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
    /// - Parameters:
    ///   - imagePathKnown: Die Quelle enthält `image_path` (Realtime, Delta, RPC-Antwort: ja).
    ///   - legacyImageKnown: Die Quelle enthält das alte Base64-Feld `imagedata` (Delta/Seitenladen: ja;
    ///     Realtime-UPDATE ohne Änderung daran und RPC-Antwort: nein).
    func apply(model: ItemModel, imagePathKnown: Bool = true, legacyImageKnown: Bool = true) {
        assignContent(from: model, includeImage: false)
        applyRemoteImage(model, pathKnown: imagePathKnown, legacyKnown: legacyImageKnown)
        if let newCreatedAt = model.createdAt { self.createdAt = newCreatedAt }
        if let newUpdatedAt = model.updatedAt { self.updatedAt = newUpdatedAt }
        self.hlcTimestamp = model.hlcTimestamp ?? 0
        self.hlcCounter = model.hlcCounter ?? 0
        self.hlcNodeId = model.hlcNodeId ?? ""
        self.lastModifiedBy = model.lastModifiedBy
        setTombstone(model.tombstone ?? false)
        self.syncStatus = .synced
    }

    /// Foto einer Remote-Zeile: Neuer Pfad → lokale Kopie verwerfen (der Prefetcher lädt nach).
    /// Gleicher Pfad → lokale Kopie behalten. Kein Pfad → altes Base64 übernehmen bzw. Foto entfernt.
    private func applyRemoteImage(_ model: ItemModel, pathKnown: Bool, legacyKnown: Bool) {
        if pathKnown, let path = model.imagePath {
            if path != imagePath {             // neues Foto: lokale Kopie verwerfen, Prefetcher lädt nach
                imagePath = path
                imageData = nil
            }
        } else if legacyKnown {                // altes Format (Base64) oder Foto entfernt
            imagePath = nil
            imageData = model.imageData
        } else if pathKnown, imagePath != nil {
            imagePath = nil                    // Foto auf einem anderen Gerät entfernt
            imageData = nil
        }
    }

    /// Schreibt die sichtbaren Felder eines Artikels (ohne CRDT- und Sync-Felder).
    /// - Parameter includeImage: Foto (Base64 und Pfad) mit übernehmen.
    func assignContent(from model: ItemModel, includeImage: Bool = true) {
        if ownerPublicId == nil { self.ownerPublicId = model.ownerPublicId }
        if includeImage {
            self.imageData = model.imageData
            self.imagePath = model.imagePath
        }
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
        entity.imagePath = model.imagePath
        entity.setTombstone(model.tombstone ?? false)
        return entity
    }
}
