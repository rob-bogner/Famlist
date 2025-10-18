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
            ownerPublicId: ownerPublicId
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
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            list: listReference,
            syncStatus: .synced
        )
        return entity
    }
}
