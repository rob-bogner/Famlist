/*
 SwiftDataListStore.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Convenience wrapper around ModelContext to manage ListEntity persistence.
 🛠 Includes: Fetch, upsert, delete helpers keeping SwiftData logic out of view models/repositories.
 🔰 Notes for Beginners: Inject a ModelContext from the environment when constructing this store; operates on the main actor.
 📝 Last Change: Keep pending deletes and add a purge helper for post-sync cleanup.
 ------------------------------------------------------------------------
*/

import Foundation // Needed for UUID and Date handling.
import SwiftData // Provides ModelContext, FetchDescriptor, and predicates.

/// Lightweight store providing CRUD helpers for ListEntity within SwiftData.
@MainActor
final class SwiftDataListStore {
    /// Underlying SwiftData context used for operations.
    private let context: ModelContext

    /// Creates the store with the provided ModelContext (typically injected from the environment).
    /// - Parameter context: The SwiftData model context backing local persistence.
    init(context: ModelContext) {
        self.context = context
    }

    /// Retrieves a list entity by its identifier.
    /// - Parameter id: The list UUID we want to load.
    /// - Returns: Matching ListEntity if present in the local store.
    func fetchList(id: UUID) throws -> ListEntity? {
        let descriptor = FetchDescriptor<ListEntity>(
            predicate: #Predicate { $0.id == id },
            sortBy: []
        )
        return try context.fetch(descriptor).first
    }

    /// Retrieves all lists for a given owner (optional filter).
    /// - Parameter ownerId: When provided, filters lists matching the owner.
    /// - Returns: Array of ListEntity objects ordered by creation date.
    func fetchLists(ownerId: UUID? = nil) throws -> [ListEntity] {
        var predicate: Predicate<ListEntity>? = nil
        if let ownerId {
            predicate = #Predicate { entity in
                entity.ownerId == ownerId
            }
        }
        let descriptor = FetchDescriptor<ListEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\ListEntity.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Inserts or updates a list based on the provided ListModel.
    /// - Parameter model: Source model (usually from Supabase) to persist locally.
    /// - Returns: The persisted ListEntity instance (new or updated).
    @discardableResult
    func upsert(model: ListModel) throws -> ListEntity {
        if let existing = try fetchList(id: model.id) {
            existing.apply(model: model)
            return existing
        }
        let entity = ListEntity.make(from: model)
        context.insert(entity)
        return entity
    }

    /// Marks a list as deleted locally (soft delete) and removes it from the context.
    /// - Parameter listId: Identifier of the list to remove.
    func delete(listId: UUID) throws {
        guard let entity = try fetchList(id: listId) else { return }
        entity.setSyncStatus(.pendingDelete)
        try save()
    }

    /// Removes a list permanently after the server confirms deletion.
    func purge(listId: UUID) throws {
        guard let entity = try fetchList(id: listId) else { return }
        context.delete(entity)
        try save()
    }

    /// Persists any pending context changes to the underlying store.
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
