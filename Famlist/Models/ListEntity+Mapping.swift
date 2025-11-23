/*
 ListEntity+Mapping.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Bridges ListEntity <-> ListModel to keep SwiftData and Supabase models aligned.
 🛠 Includes: Conversion helpers to create/update ListEntity from ListModel and expose ListModel snapshots.
 🔰 Notes for Beginners: Use these helpers so mapping logic stays in one place; avoid duplicating in repositories.
 📝 Last Change: Initial creation for local-first migration step.
 ------------------------------------------------------------------------
*/

import Foundation // Provides Date and UUID used by the conversion helpers.

/// Extension housing mapping helpers between ListEntity (SwiftData) and ListModel (network layer).
extension ListEntity {
    /// Produces a ListModel representation from the SwiftData entity.
    /// - Returns: Optional ListModel because ownerId can be nil when the entity is created offline.
    func toListModel() -> ListModel? {
        guard let ownerId else { return nil } // Without owner the network model would be invalid.
        return ListModel(
            id: id,
            ownerId: ownerId,
            title: title,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Applies fields from a ListModel onto the existing SwiftData entity.
    /// - Parameter model: Source ListModel fetched from Supabase.
    func apply(model: ListModel) {
        self.ownerId = model.ownerId
        self.title = model.title
        self.isDefault = model.isDefault
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.deletedAt = nil
        self.setSyncStatus(.synced)
    }

    /// Creates a new ListEntity by mirroring the provided ListModel.
    /// - Parameter model: Source ListModel to map.
    /// - Returns: Newly initialised ListEntity pre-populated with synced status.
    static func make(from model: ListModel) -> ListEntity {
        ListEntity(
            id: model.id,
            ownerId: model.ownerId,
            title: model.title,
            isDefault: model.isDefault,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            deletedAt: nil,
            items: [],
            syncStatus: .synced
        )
    }
}
