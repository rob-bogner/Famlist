/*
 ItemEntity+Mapping.swift
 GroceryGenius
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Bridges ItemEntity <-> ItemModel for the local-first data pipeline.
 🛠 Includes: Helper methods to convert between SwiftData entities and the existing ItemModel struct.
 🔰 Notes for Beginners: Use these helpers to keep mapping logic consistent across repositories and sync jobs.
 📝 Last Change: Initial creation for local-first migration step.
 ------------------------------------------------------------------------
*/

import Foundation // Needed for UUID conversion between String and UUID representations.

/// Mapping helpers from ItemEntity (SwiftData) to ItemModel (shared model for UI/network).
extension ItemEntity {
    /// Builds an ItemModel snapshot from the SwiftData entity.
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
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId.uuidString,
            ownerPublicId: ownerPublicId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Applies fields from an ItemModel onto the existing SwiftData entity and marks as synced.
    /// - Parameter model: Source ItemModel typically fetched from Supabase.
    func apply(model: ItemModel) {
        self.ownerPublicId = model.ownerPublicId
        self.imageData = model.imageData
        self.name = model.name
        self.units = model.units
        self.measure = model.measure
        self.price = model.price
        self.isChecked = model.isChecked
        self.category = model.category
        self.productDescription = model.productDescription
        self.brand = model.brand
        if let newListIdString = model.listId, let newListId = UUID(uuidString: newListIdString) {
            self.listId = newListId
        }
        if let newCreatedAt = model.createdAt {
            self.createdAt = newCreatedAt
        }
        if let newUpdatedAt = model.updatedAt {
            self.updatedAt = newUpdatedAt
        }
        
        // Apply CRDT metadata if present
        if let hlcTimestamp = model.hlcTimestamp {
            self.hlcTimestamp = hlcTimestamp
        }
        if let hlcCounter = model.hlcCounter {
            self.hlcCounter = hlcCounter
        }
        if let hlcNodeId = model.hlcNodeId {
            self.hlcNodeId = hlcNodeId
        }
        if let tombstone = model.tombstone {
            self.tombstone = tombstone
        }
        if let lastModifiedBy = model.lastModifiedBy {
            self.lastModifiedBy = lastModifiedBy
        }
        
        self.deletedAt = nil
        self.setSyncStatus(.synced)
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
            category: model.category,
            productDescription: model.productDescription,
            brand: model.brand,
            createdAt: model.createdAt ?? Date(),
            updatedAt: model.updatedAt ?? Date(),
            deletedAt: nil,
            list: listReference,
            syncStatus: .synced,
            hlcTimestamp: model.hlcTimestamp ?? Int64(Date().timeIntervalSince1970 * 1000),
            hlcCounter: model.hlcCounter ?? 0,
            hlcNodeId: model.hlcNodeId ?? "",
            tombstone: model.tombstone ?? false,
            lastModifiedBy: model.lastModifiedBy
        )
        return entity
    }
}
